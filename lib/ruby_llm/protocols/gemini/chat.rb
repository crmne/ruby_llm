# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Chat methods for the Gemini API implementation
      module Chat
        FINISH_REASONS = {
          'STOP' => :stop, 'MAX_TOKENS' => :max_tokens, 'CONTINUATION' => nil,
          'SAFETY' => :content_filter, 'RECITATION' => :content_filter, 'BLOCKLIST' => :content_filter,
          'PROHIBITED_CONTENT' => :content_filter, 'SPII' => :content_filter, 'IMAGE_SAFETY' => :content_filter,
          'IMAGE_RECITATION' => :content_filter, 'IMAGE_PROHIBITED_CONTENT' => :content_filter,
          'MODEL_ARMOR' => :content_filter
        }.freeze

        GEMINI_INLINE_FILE_THRESHOLD = 20 * 1024 * 1024
        VERTEX_INLINE_FILE_THRESHOLD = 7 * 1024 * 1024

        module_function

        def finish_reasons = FINISH_REASONS

        def normalize_finish_reason(reason)
          return nil if reason.nil?

          finish_reasons.fetch(reason.to_s) { reason.to_s.to_sym }
        end

        def completion_url
          "models/#{@model.id}:generateContent"
        end

        # rubocop:disable-next Metrics/PerceivedComplexity,Lint/UnusedMethodArgument
        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil, schema: nil,
                           thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          warn_unsupported_citations(model) if citations && !model.supports?(:citations)
          tool_prefs ||= {}
          unfinished = messages.last if messages.last&.continuation
          payload = {
            contents: render_messages(messages.reject { |msg| msg.role == :system || msg.equal?(unfinished) }),
            generationConfig: {}
          }
          payload[:continuationToken] = unfinished.continuation if unfinished
          system_instruction = render_system_instruction(messages)
          payload[:systemInstruction] = system_instruction if system_instruction

          payload[:generationConfig][:temperature] = temperature unless temperature.nil?
          payload[:generationConfig][:maxOutputTokens] = max_output_tokens unless max_output_tokens.nil?

          payload[:generationConfig].merge!(structured_output_config(schema)) if schema
          payload[:generationConfig][:thinkingConfig] = build_thinking_config(model, thinking) if thinking&.enabled?

          if tools.any?
            payload[:tools] = render_tools(tools)
            # Gemini doesn't support controlling parallel tool calls
            payload[:toolConfig] = build_tool_config(tool_prefs[:choice]) unless tool_prefs[:choice].nil?
          end

          payload[:cachedContent] = cache_name(caching[:id]) if caching.is_a?(Hash) && caching[:id]
          maybe_log_implicit_caching_note(messages, caching)

          payload
        end

        def maybe_log_implicit_caching_note(messages, caching)
          return if caching == false
          return unless (caching && !caching[:id]) || messages.any?(&:cache_until_here?)

          RubyLLM.logger.debug(
            'Gemini caches repeated prompt prefixes automatically (implicit caching). ' \
            'For explicit caching, create a cache with RubyLLM.cache and attach it with ' \
            'chat.with_caching(id: cache).'
          )
        end

        def warn_unsupported_citations(model)
          RubyLLM.logger.warn(
            "#{model.id} does not support citations according to the model registry. " \
            'Gemini citations come from Google Search grounding: ' \
            'with_provider_options(tools: [{ google_search: {} }]).'
          )
        end

        def count_tokens_url
          "models/#{@model.id}:countTokens"
        end

        def render_count_tokens_payload(messages, model:, **)
          request = count_tokens_request(messages, model: model, **)
          { generateContentRequest: request.merge(model: "models/#{model.id}") }
        end

        def count_tokens_request(messages, tools:, model:, tool_prefs: nil, thinking: nil, schema: nil,
                                 citations: false, caching: nil)
          render_payload(
            messages,
            tools: tools,
            tool_prefs: tool_prefs,
            temperature: nil,
            model: model,
            schema: schema,
            thinking: thinking,
            citations: citations,
            caching: caching
          ).slice(:contents, :systemInstruction, :tools)
        end

        def parse_count_tokens_response(response)
          response.body['totalTokens']
        end

        def build_thinking_config(_model, thinking)
          off = thinking.enabled == false || (thinking.budget.is_a?(Integer) && thinking.budget.zero?)
          return { includeThoughts: false, thinkingBudget: 0 } if off

          config = { includeThoughts: true }

          config[:thinkingLevel] = thinking.effort.to_s if thinking.effort
          config[:thinkingBudget] = thinking.budget if thinking.budget.is_a?(Integer)
          config[:thinkingBudget] = -1 if thinking.enabled == true

          config
        end

        def provider_file_references?
          true
        end

        def default_large_file_upload_threshold
          @provider.slug == 'vertexai' ? VERTEX_INLINE_FILE_THRESHOLD : GEMINI_INLINE_FILE_THRESHOLD
        end

        def provider_file_attachable?(attachment)
          attachment.image? || attachment.video? || attachment.audio? || attachment.pdf? || attachment.text?
        end

        private

        def render_system_instruction(messages)
          parts = messages.select { |msg| msg.role == :system }.flat_map do |msg|
            text = msg.content.to_s
            Media.render_content(text.empty? ? nil : text, msg.attachments)
          end

          { parts: parts } if parts.any?
        end

        def render_messages(messages)
          MessageFormatter.new(self, messages).format
        end

        def render_role(role)
          case role
          when :assistant then 'model'
          when :system, :tool then 'user'
          else role.to_s
          end
        end

        def render_parts(msg)
          if msg.role == :assistant && msg.raw_content.is_a?(Array)
            msg.raw_content
          elsif msg.tool_call?
            render_tool_call(msg)
          elsif msg.tool_result?
            render_tool_result(msg)
          else
            render_message_parts(msg)
          end
        end

        def render_message_parts(msg)
          parts = Media.render_content(msg.content, msg.attachments)
          thinking = msg.thinking if msg.role == :assistant
          return parts unless thinking

          signature = own_signature(msg)
          parts = sign_last_part(parts, signature) if signature
          thinking.text ? [{ thought: true, text: thinking.text }, *parts] : parts
        end

        # Gemini signs the last part of an answer. An answer without parts gets
        # the empty text part a stream ends with: Gemini refuses a part without data.
        def sign_last_part(parts, signature)
          parts = [Media.render_text('')] if parts.empty?
          [*parts[...-1], parts.last.merge(thoughtSignature: signature)]
        end

        def parse_completion_body(data, raw:)
          parts = data.dig('candidates', 0, 'content', 'parts') || []
          tool_calls = parse_tool_calls(data)
          content, attachments = parse_content(data)
          continuation = parse_continuation(data)

          Message.new(
            role: :assistant,
            content: content,
            attachments: attachments,
            citations: parse_citations(data, parts),
            thinking: Thinking.build(
              text: parse_thought_parts(parts),
              signature: parse_thought_signature(parts)
            ),
            tool_calls: tool_calls,
            server_tool_calls: parse_server_tool_calls(data, parts),
            raw_content: (without_search_suggestions(parts) if continuation || parts.any? { |p| server_tool_part?(p) }),
            continuation: continuation,
            input_tokens: input_tokens(data),
            output_tokens: calculate_output_tokens(data),
            cache_read_tokens: data.dig('usageMetadata', 'cachedContentTokenCount'),
            thinking_tokens: data.dig('usageMetadata', 'thoughtsTokenCount'),
            server_tool_use: parse_server_tool_use(data),
            finish_reason: normalize_finish_reason(
              data.dig('candidates', 0, 'finishReason') || data.dig('promptFeedback', 'blockReason')
            ),
            model: data['modelVersion'] || @model&.id,
            raw: raw
          )
        end

        # Long decode hands back a token whenever it pauses, including at
        # stream checkpoints and on MAX_TOKENS; only CONTINUATION leaves the
        # response unfinished.
        def parse_continuation(data)
          candidate = data.dig('candidates', 0) || {}
          candidate['continuationToken'] if candidate['finishReason'] == 'CONTINUATION'
        end

        # Gemini 3 bills each distinct, non-empty query a grounding ran.
        def parse_server_tool_use(data)
          searches = Array(data['candidates']).sum do |candidate|
            Array(candidate.dig('groundingMetadata', 'webSearchQueries')).reject(&:empty?).uniq.size
          end
          { 'web_search_requests' => searches }
        end

        # Gemini reports what a server-side tool loaded for the model, such as
        # the frames of an agentic video, apart from the prompt, and bills it
        # as input.
        def input_tokens(data)
          usage = data['usageMetadata'] || {}
          prompt_tokens = usage['promptTokenCount']
          return unless prompt_tokens

          [prompt_tokens.to_i + usage['toolUsePromptTokenCount'].to_i - usage['cachedContentTokenCount'].to_i, 0].max
        end

        def parse_content(data)
          candidate = data.dig('candidates', 0)
          return ['', []] unless candidate

          parts = candidate.dig('content', 'parts')
          return ['', []] unless parts&.any?

          non_thought_parts = parts.reject { |part| part['thought'] }
          return ['', []] unless non_thought_parts.any?

          build_response_content(non_thought_parts)
        end

        # Code execution runs come back as parts inside the model turn and
        # must be replayed in history; search and URL fetches come back as
        # response-level metadata.
        def server_tool_part?(part)
          part.key?('executableCode') || part.key?('codeExecutionResult')
        end

        # Google's terms forbid storing search suggestions, and Gemini takes
        # a replayed search result without them.
        def without_search_suggestions(parts)
          parts.map do |part|
            tool_response = part['toolResponse']
            response = tool_response&.dig('response')
            next part unless response.is_a?(Hash) && response.key?('search_suggestions')

            part.merge('toolResponse' => tool_response.merge('response' => response.except('search_suggestions')))
          end
        end

        def parse_server_tool_calls(data, parts)
          calls = parts.select { |part| server_tool_part?(part) }.map do |part|
            ServerToolCall.new(
              type: part.key?('executableCode') ? 'executable_code' : 'code_execution_result',
              input: part['executableCode'],
              result: part['codeExecutionResult'],
              raw: part
            )
          end
          calls.concat(metadata_server_tool_calls(data))
          calls
        end

        def metadata_server_tool_calls(data)
          candidate = data.dig('candidates', 0) || {}
          calls = []

          queries = candidate.dig('groundingMetadata', 'webSearchQueries')
          if queries&.any?
            calls << ServerToolCall.new(type: 'google_search', input: { 'queries' => queries },
                                        raw: { 'webSearchQueries' => queries },
                                        search_suggestions: candidate.dig('groundingMetadata', 'searchEntryPoint',
                                                                          'renderedContent'))
          end

          url_metadata = candidate['urlContextMetadata']
          calls << ServerToolCall.new(type: 'url_context', result: url_metadata, raw: url_metadata) if url_metadata
          calls
        end

        # Normalizes grounding metadata (Google Search grounding) into citations.
        def parse_citations(data, parts)
          metadata = data.dig('candidates', 0, 'groundingMetadata')
          return [] unless metadata

          chunks = metadata['groundingChunks'] || []
          supports = metadata['groundingSupports'] || []
          return chunk_citations(chunks) if supports.empty?

          supports.flat_map { |support| support_citations(support, chunks, parts) }
        end

        def support_citations(support, chunks, parts)
          segment = support['segment'] || {}
          start_index, end_index = citation_indices(parts, segment)

          Array(support['groundingChunkIndices']).filter_map do |index|
            source = chunk_source(chunks[index])
            next unless source

            Citation.new(
              url: source['uri'],
              title: source['title'],
              text: segment['text'],
              start_index: start_index,
              end_index: end_index,
              source_index: index
            )
          end
        end

        def citation_indices(parts, segment)
          indices = [segment.fetch('startIndex', 0), segment['endIndex']].map do |byte_index|
            citation_offset(parts, segment, byte_index)
          end
          indices.all? && indices.first <= indices.last ? indices : [nil, nil]
        end

        # Without a partIndex, offsets count across the visible text, which
        # keeps thinking parts ahead of the answer from absorbing the span.
        def citation_offset(parts, segment, byte_index)
          return byte_to_char_index(visible_text(parts), byte_index) unless segment.key?('partIndex')

          part_index = segment['partIndex']
          return unless part_index.is_a?(Integer) && part_index.between?(0, parts.length - 1)

          part = parts[part_index]
          return if part['thought']

          index = byte_to_char_index(part['text'], byte_index)
          visible_text(parts.take(part_index)).length + index if index
        end

        def visible_text(parts)
          parts.reject { |part| part['thought'] }.sum('') { |part| part['text'].to_s }
        end

        def chunk_citations(chunks)
          chunks.each_with_index.filter_map do |chunk, index|
            source = chunk_source(chunk)
            next unless source

            Citation.new(url: source['uri'], title: source['title'], source_index: index)
          end
        end

        def chunk_source(chunk)
          return nil unless chunk.is_a?(Hash)

          chunk['web'] || chunk['retrievedContext']
        end

        # Grounding segment indices are byte offsets within the selected UTF-8 part.
        def byte_to_char_index(content, byte_index)
          return unless content.is_a?(String) && byte_index.is_a?(Integer) &&
                        byte_index.between?(0, content.bytesize)

          prefix = content.byteslice(0, byte_index)
          prefix.length if prefix.valid_encoding?
        end

        def parse_thought_parts(parts)
          thought_parts = parts.select { |p| p['thought'] }
          thoughts = thought_parts.filter_map { |p| p['text'] }.join
          thoughts.empty? ? nil : thoughts
        end

        # Agentic video navigation steps carry signatures of their own, which
        # Gemini refuses on the answer they precede.
        def parse_thought_signature(parts)
          parts.each do |part|
            next if part.key?('toolCall') || part.key?('toolResponse')

            signature = part['thoughtSignature'] ||
                        part['thought_signature'] ||
                        part.dig('functionCall', 'thoughtSignature') ||
                        part.dig('functionCall', 'thought_signature')
            return signature if signature
          end

          nil
        end

        def calculate_output_tokens(data)
          counts = (data['usageMetadata'] || {}).values_at('candidatesTokenCount', 'thoughtsTokenCount').compact
          counts.sum unless counts.empty?
        end

        def build_json_schema(schema)
          normalized = RubyLLM::Support::Utils.deep_dup(schema[:schema])
          normalized.delete(:strict)
          normalized.delete('strict')
          Schemas.render_schema(RubyLLM::Support::Utils.deep_stringify_keys(normalized))
        end

        def structured_output_config(schema)
          {
            responseMimeType: 'application/json',
            responseJsonSchema: build_json_schema(schema)
          }
        end

        # formats a message
        class MessageFormatter
          def initialize(provider, messages)
            @provider = provider
            @messages = messages
            @index = 0
            @tool_call_names = {}
            @turn_start = messages.rindex { |message| message.role == :user }
          end

          def format
            formatted = []

            while current_message
              if tool_message?(current_message)
                tool_parts, next_index = collect_tool_parts
                formatted << build_tool_response(tool_parts)
                @index = next_index
              else
                remember_tool_calls if current_message.tool_call?
                formatted << build_standard_message(current_message)
                @index += 1
              end
            end

            formatted
          end

          private

          def current_message
            @messages[@index]
          end

          def tool_message?(message)
            message&.role == :tool
          end

          def collect_tool_parts
            results = []
            index = @index

            while tool_message?(@messages[index])
              results << @messages[index]
              index += 1
            end

            parts = in_call_order(results).flat_map do |tool_message|
              render_tool_result(tool_message, @tool_call_names.delete(tool_message.tool_call_id))
            end

            [parts, index]
          end

          # functionResponse parts carry no call id, so Gemini pairs them with
          # the functionCall parts by position. Results that arrived out of
          # call order have to be put back in it.
          def in_call_order(tool_messages)
            order = @tool_call_names.keys
            tool_messages.sort_by.with_index do |tool_message, index|
              [order.index(tool_message.tool_call_id) || order.size, index]
            end
          end

          def build_tool_response(parts)
            { role: 'user', parts: parts }
          end

          def remember_tool_calls
            current_message.tool_calls.each do |tool_call_id, tool_call|
              @tool_call_names[tool_call_id] = tool_call.name
            end
          end

          def build_standard_message(message)
            parts = @provider.send(:render_parts, message)
            parts = @provider.send(:sign_step, parts) if message.tool_call? && current_turn?

            {
              role: @provider.send(:render_role, message.role),
              parts: parts
            }
          end

          # Gemini checks signatures only in the current turn, which starts at
          # the last user message.
          def current_turn?
            @turn_start.nil? || @index > @turn_start
          end

          def render_tool_result(message, tool_name)
            @provider.send(:render_tool_result, message, tool_name)
          end
        end
      end
    end
  end
end
