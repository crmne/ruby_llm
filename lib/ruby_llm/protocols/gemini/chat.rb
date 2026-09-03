# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Chat methods for the Gemini API implementation
      module Chat
        FINISH_REASONS = {
          'STOP' => :stop, 'MAX_TOKENS' => :max_tokens,
          'SAFETY' => :content_filter, 'RECITATION' => :content_filter, 'BLOCKLIST' => :content_filter,
          'PROHIBITED_CONTENT' => :content_filter, 'SPII' => :content_filter, 'IMAGE_SAFETY' => :content_filter,
          'IMAGE_RECITATION' => :content_filter, 'IMAGE_PROHIBITED_CONTENT' => :content_filter,
          'MODEL_ARMOR' => :content_filter
        }.freeze

        GEMINI_INLINE_FILE_THRESHOLD = 20 * 1024 * 1024
        VERTEX_INLINE_FILE_THRESHOLD = 7 * 1024 * 1024
        GEMINI_FILE_UPLOAD_LIMIT = 2 * 1024 * 1024 * 1024

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
          payload = {
            contents: format_messages(messages.reject { |msg| msg.role == :system }),
            generationConfig: {}
          }
          system_instruction = format_system_instruction(messages)
          payload[:systemInstruction] = system_instruction if system_instruction

          payload[:generationConfig][:temperature] = temperature unless temperature.nil?
          payload[:generationConfig][:maxOutputTokens] = max_output_tokens unless max_output_tokens.nil?

          payload[:generationConfig].merge!(structured_output_config(schema)) if schema
          payload[:generationConfig][:thinkingConfig] = build_thinking_config(model, thinking) if thinking&.enabled?

          if tools.any?
            payload[:tools] = format_tools(tools)
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

        def render_count_tokens_payload(messages, model:, **options)
          request = count_tokens_request(messages, model: model, **options)
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
          return { includeThoughts: false, thinkingBudget: 0 } if thinking.enabled == false

          config = { includeThoughts: true }

          config[:thinkingLevel] = thinking.effort.to_s if thinking.effort
          config[:thinkingBudget] = thinking.budget if thinking.budget.is_a?(Integer)
          config[:thinkingBudget] = -1 if thinking.enabled == true

          config
        end

        def supports_provider_file_references?
          true
        end

        def default_large_file_upload_threshold
          @provider.slug == 'vertexai' ? VERTEX_INLINE_FILE_THRESHOLD : GEMINI_INLINE_FILE_THRESHOLD
        end

        def provider_file_upload_limit
          GEMINI_FILE_UPLOAD_LIMIT
        end

        def provider_file_attachable?(attachment)
          attachment.image? || attachment.video? || attachment.audio? || attachment.pdf? || attachment.text?
        end

        private

        def format_system_instruction(messages)
          parts = messages.select { |msg| msg.role == :system }.flat_map do |msg|
            text = msg.content.to_s
            Media.format_content(text.empty? ? nil : text, msg.attachments)
          end

          { parts: parts } if parts.any?
        end

        def format_messages(messages)
          MessageFormatter.new(self, messages).format
        end

        def format_role(role)
          case role
          when :assistant then 'model'
          when :system, :tool then 'user'
          else role.to_s
          end
        end

        def format_parts(msg)
          if msg.role == :assistant && msg.raw_content
            msg.raw_content
          elsif msg.tool_call?
            format_tool_call(msg)
          elsif msg.tool_result?
            format_tool_result(msg)
          else
            format_message_parts(msg)
          end
        end

        def format_message_parts(msg)
          parts = []

          parts << build_thought_part(msg.thinking) if msg.role == :assistant && msg.thinking

          parts.concat(Media.format_content(msg.content, msg.attachments))
          parts
        end

        def build_thought_part(thinking)
          part = { thought: true }
          part[:text] = thinking.text if thinking.text
          part[:thoughtSignature] = thinking.signature if thinking.signature
          part
        end

        def parse_completion_body(data, raw:)
          parts = data.dig('candidates', 0, 'content', 'parts') || []
          tool_calls = extract_tool_calls(data)
          content, attachments = parse_content(data)

          Message.new(
            role: :assistant,
            content: content,
            attachments: attachments,
            citations: extract_citations(data, content),
            thinking: Thinking.build(
              text: extract_thought_parts(parts),
              signature: extract_thought_signature(parts)
            ),
            tool_calls: tool_calls,
            server_tool_calls: extract_server_tool_calls(data, parts),
            raw_content: parts.any? { |part| server_tool_part?(part) } ? parts : nil,
            input_tokens: input_tokens(data),
            output_tokens: calculate_output_tokens(data),
            cache_read_tokens: data.dig('usageMetadata', 'cachedContentTokenCount'),
            thinking_tokens: data.dig('usageMetadata', 'thoughtsTokenCount'),
            finish_reason: normalize_finish_reason(
              data.dig('candidates', 0, 'finishReason') || data.dig('promptFeedback', 'blockReason')
            ),
            model: data['modelVersion'] || @model&.id,
            raw: raw
          )
        end

        def input_tokens(data)
          prompt_tokens = data.dig('usageMetadata', 'promptTokenCount')
          return unless prompt_tokens

          [prompt_tokens.to_i - data.dig('usageMetadata', 'cachedContentTokenCount').to_i, 0].max
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

        def extract_server_tool_calls(data, parts)
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
                                        raw: { 'webSearchQueries' => queries })
          end

          url_metadata = candidate['urlContextMetadata']
          calls << ServerToolCall.new(type: 'url_context', result: url_metadata, raw: url_metadata) if url_metadata
          calls
        end

        # Normalizes grounding metadata (Google Search grounding) into citations.
        def extract_citations(data, content)
          metadata = data.dig('candidates', 0, 'groundingMetadata')
          return [] unless metadata

          chunks = metadata['groundingChunks'] || []
          supports = metadata['groundingSupports'] || []
          return chunk_citations(chunks) if supports.empty?

          supports.flat_map { |support| support_citations(support, chunks, content) }
        end

        def support_citations(support, chunks, content)
          segment = support['segment'] || {}
          end_index = segment['endIndex']
          start_index = segment['startIndex'] || (0 if end_index)

          Array(support['groundingChunkIndices']).filter_map do |index|
            source = chunk_source(chunks[index])
            next unless source

            Citation.new(
              url: source['uri'],
              title: source['title'],
              text: segment['text'],
              start_index: byte_to_char_index(content, start_index),
              end_index: byte_to_char_index(content, end_index),
              source_index: index
            )
          end
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

        # Grounding segment indices are byte offsets into the UTF-8 response text.
        def byte_to_char_index(content, byte_index)
          return nil unless content.is_a?(String) && byte_index

          content.byteslice(0, byte_index)&.length
        end

        def extract_thought_parts(parts)
          thought_parts = parts.select { |p| p['thought'] }
          thoughts = thought_parts.filter_map { |p| p['text'] }.join
          thoughts.empty? ? nil : thoughts
        end

        def extract_thought_signature(parts)
          parts.each do |part|
            signature = part['thoughtSignature'] ||
                        part['thought_signature'] ||
                        part.dig('functionCall', 'thoughtSignature') ||
                        part.dig('functionCall', 'thought_signature')
            return signature if signature
          end

          nil
        end

        def calculate_output_tokens(data)
          candidates = data.dig('usageMetadata', 'candidatesTokenCount') || 0
          thoughts = data.dig('usageMetadata', 'thoughtsTokenCount') || 0
          candidates + thoughts
        end

        def build_json_schema(schema)
          normalized = RubyLLM::Utils.deep_dup(schema[:schema])
          normalized.delete(:strict)
          normalized.delete('strict')
          RubyLLM::Utils.deep_stringify_keys(normalized)
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
              format_tool_result(tool_message, @tool_call_names.delete(tool_message.tool_call_id))
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
            {
              role: @provider.send(:format_role, message.role),
              parts: @provider.send(:format_parts, message)
            }
          end

          def format_tool_result(message, tool_name)
            @provider.send(:format_tool_result, message, tool_name)
          end
        end
      end
    end
  end
end
