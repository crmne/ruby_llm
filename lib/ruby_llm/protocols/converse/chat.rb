# frozen_string_literal: true

require 'json'

module RubyLLM
  module Protocols
    class Converse
      # Chat methods for Bedrock Converse API.
      module Chat
        FINISH_REASONS = {
          'end_turn' => :stop, 'stop_sequence' => :stop, 'max_tokens' => :max_tokens,
          'model_context_window_exceeded' => :max_tokens, 'tool_use' => :tool_calls,
          'guardrail_intervened' => :content_filter, 'content_filtered' => :content_filter
        }.freeze

        BEDROCK_INLINE_DOCUMENT_LIMIT = 4_500_000
        PROMPT_CACHE_OPTIONS = %i[ttl].freeze
        # Bedrock accepts at most four cache points in one request, and
        # Converse takes them only for Claude and Nova models; Nova takes none
        # in toolConfig.tools. See "Supported models, Regions, and explicit
        # caching limits" in
        # https://docs.aws.amazon.com/bedrock/latest/userguide/prompt-caching.html
        MAX_CACHE_POINTS = 4
        CACHE_POINT_MODELS = %w[anthropic. amazon.nova].freeze
        TOOL_CACHE_POINT_MODELS = %w[anthropic.].freeze
        # Converse refuses searchResult blocks from every model but Claude, so an
        # application inference profile, which doesn't name its model, gets text.
        SEARCH_RESULT_MODELS = %w[anthropic.].freeze
        # Bedrock forwards an S3 source to other models untranslated, and
        # Claude rejects it.
        S3_SOURCE_MODELS = %w[amazon.nova].freeze
        OFFICE_DOCUMENT_FORMATS = %w[doc docx xls xlsx].freeze
        CACHE_LIFETIME_UNITS = { 's' => 1, 'm' => 60, 'h' => 3600 }.freeze
        COUNT_TOKENS_KEYS = %i[messages system toolConfig additionalModelRequestFields].freeze

        module_function

        def finish_reasons = FINISH_REASONS

        def normalize_finish_reason(reason)
          return nil if reason.nil?

          finish_reasons.fetch(reason.to_s) { reason.to_s.to_sym }
        end

        def completion_url
          "/model/#{escape_model_id(@model.id)}/converse"
        end

        # Application inference profile ARNs contain '/', but Bedrock expects the model id
        # to remain one path segment.
        def escape_model_id(model_id)
          model_id.to_s.gsub('/', '%2F')
        end

        # rubocop:disable-next Lint/UnusedMethodArgument
        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil,
                           schema: nil, thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          tool_prefs ||= {}
          max_output_tokens ||= model.max_output_tokens
          @used_document_names = {}
          system_messages, chat_messages = messages.partition { |msg| msg.role == :system }
          prompt_cache_options(caching)
          payload = {
            messages: render_messages(chat_messages, caching:, citations:, search_results: search_results?(model))
          }

          system_blocks = render_system(system_messages, caching:)
          payload[:system] = system_blocks unless system_blocks.empty?

          payload[:inferenceConfig] = render_inference_config(model, temperature, max_output_tokens)

          tool_config = render_tool_config(tools, tool_prefs)
          payload[:toolConfig] = tool_config if tool_config

          additional_fields = render_additional_model_request_fields(thinking, model, max_output_tokens)
          additional_fields = bind_replayed_thinking(additional_fields, payload[:messages], model)
          payload[:additionalModelRequestFields] = additional_fields if additional_fields

          output_config = build_output_config(schema)
          payload[:outputConfig] = output_config if output_config

          add_automatic_cache_points(payload, model, caching)
          payload
        end

        def count_tokens_url
          "/model/#{escape_model_id(@model.id)}/count-tokens"
        end

        def render_count_tokens_payload(messages, tools:, model:, tool_prefs: nil, thinking: nil, schema: nil,
                                        citations: false, caching: nil)
          request = render_payload(
            messages,
            tools: tools,
            tool_prefs: tool_prefs,
            temperature: nil,
            model: model,
            schema: schema,
            thinking: thinking,
            citations: citations,
            caching: caching
          ).slice(*COUNT_TOKENS_KEYS)

          { input: { converse: request } }
        end

        def parse_count_tokens_response(response)
          response.body['inputTokens']
        end

        def provider_file_references?
          S3_SOURCE_MODELS.any? { |prefix| foundation_model_id(@model&.id).start_with?(prefix) }
        end

        def default_large_file_upload_threshold
          BEDROCK_INLINE_DOCUMENT_LIMIT
        end

        def provider_file_attachable?(attachment)
          (attachment.pdf? || attachment.document? || attachment.text?) &&
            Media.supported_document_format?(attachment)
        end

        def parse_completion_body(data, raw:)
          content_blocks = data.dig('output', 'message', 'content') || []
          usage = data['usage'] || {}
          thinking_text, thinking_signature = parse_thinking(content_blocks)
          text_content, citations = parse_text_and_citations(content_blocks)

          Message.new(
            role: :assistant,
            content: text_content,
            citations: citations,
            thinking: Thinking.build(text: thinking_text, signature: thinking_signature),
            raw_reasoning: parse_thinking_blocks(content_blocks),
            tool_calls: parse_tool_calls(content_blocks),
            server_tool_calls: parse_server_tool_calls(content_blocks),
            input_tokens: input_tokens(usage),
            output_tokens: usage['outputTokens'],
            cache_read_tokens: usage['cacheReadInputTokens'],
            cache_write_tokens: usage['cacheWriteInputTokens'],
            cache_write_tokens_by_ttl: cache_write_by_ttl(usage),
            thinking_tokens: reasoning_tokens(usage),
            finish_reason: normalize_finish_reason(data['stopReason']),
            model: data['modelId'] || @model&.id,
            raw: raw
          )
        end

        def input_tokens(usage)
          # AWS Bedrock reports inputTokens as already non-cached; cacheReadInputTokens and
          # cacheWriteInputTokens are separate buckets, not folded into inputTokens. Subtracting
          # them (as inclusive providers require) understates input and floors to zero on cache
          # hits. See https://docs.aws.amazon.com/bedrock/latest/userguide/prompt-caching.html
          usage['inputTokens']
        end

        def reasoning_tokens(usage)
          usage['reasoningTokens'] || usage.dig('outputTokensDetails', 'reasoningTokens')
        end

        def cache_write_by_ttl(usage)
          details = usage['cacheDetails']
          return unless details.is_a?(Array)

          details.each_with_object(Hash.new(0)) do |detail, counts|
            counts[detail['ttl']] += detail['inputTokens'].to_i if detail['ttl']
          end
        end

        def render_messages(messages, caching: nil, citations: false, search_results: false)
          rendered = []
          tool_result_blocks = []

          messages.each do |msg|
            if msg.tool_result?
              tool_result_blocks.concat(render_tool_result_blocks(msg, caching:, citations:, search_results:))
              next
            end

            message = render_non_tool_message(msg, caching:, citations:)
            next tool_result_blocks.concat(message[:content]) if joins_tool_results?(message, tool_result_blocks)

            unless tool_result_blocks.empty?
              rendered << { role: 'user', content: tool_result_blocks }
              tool_result_blocks = []
            end
            rendered << message if message
          end

          rendered << { role: 'user', content: tool_result_blocks } unless tool_result_blocks.empty?
          rendered
        end

        def joins_tool_results?(message, tool_result_blocks)
          message && message[:role] == 'user' && !tool_result_blocks.empty?
        end

        def render_non_tool_message(msg, caching: nil, citations: false)
          content = render_message_content(msg, caching:, citations:)
          return nil if content.empty?

          {
            role: render_role(msg.role),
            content: content
          }
        end

        def render_message_content(msg, caching: nil, citations: false)
          blocks = render_structured_message_content(msg, citations:)

          if msg.tool_call?
            msg.tool_calls.each_value do |tool_call|
              blocks << {
                toolUse: {
                  toolUseId: tool_call.provider_call_id,
                  name: tool_call.name,
                  input: tool_call.arguments
                }
              }
            end
          end
          blocks << converse_cache_block_for(caching, ttl: msg.cache_ttl) if cache_boundary?(msg, caching:)

          blocks
        end

        def render_structured_message_content(msg, citations: false)
          blocks = msg.role == :assistant ? render_thinking_blocks(msg) : []

          blocks.concat(
            Media.render_content(msg.content, msg.attachments, used_document_names: @used_document_names, citations:)
          )

          blocks
        end

        # Reasoning rebuilt from thinking text goes back only to the provider
        # that produced it: Claude refuses another provider's signature, and
        # a block without one.
        def render_thinking_blocks(msg)
          blocks = msg.raw_reasoning['converse'] if msg.raw_reasoning.is_a?(Hash)
          return Support::Utils.deep_dup(blocks) if blocks
          return [] unless msg.thinking && producer_slug(msg) == @provider.slug

          [render_thinking_block(msg.thinking)].compact
        end

        def render_tool_result_blocks(msg, caching: nil, citations: false, search_results: false)
          blocks = [render_tool_result_block(msg, citations:, search_results:)]
          blocks << converse_cache_block_for(caching, ttl: msg.cache_ttl) if cache_boundary?(msg, caching:)
          blocks
        end

        def render_tool_result_block(msg, citations: false, search_results: false)
          {
            toolResult: {
              toolUseId: msg.provider_call_id,
              content: render_tool_result_content(msg, citations:, search_results:)
            }
          }
        end

        def render_tool_result_content(msg, citations: false, search_results: false)
          results = RubyLLM::SearchResults.from_content(msg.content) if search_results
          return results.results.map { |result| search_result_block(result) } if results

          content = msg.content unless msg.content&.strip&.empty?
          blocks = Media.render_content(content, msg.attachments, used_document_names: @used_document_names, citations:)
          blocks.empty? ? [text_tool_result_block(nil)] : blocks
        end

        def search_result_block(result)
          {
            searchResult: {
              source: result[:source_id] || result[:url] || result[:title],
              title: result[:title],
              content: [{ text: result[:text] }],
              citations: { enabled: true }
            }
          }
        end

        def text_tool_result_block(text)
          text = text.to_s
          text = '(no output)' if text.empty?
          { text: text }
        end

        def render_role(role)
          case role
          when :assistant then 'assistant'
          else 'user'
          end
        end

        def render_system(messages, caching: nil)
          messages.flat_map do |msg|
            blocks = Media.render_content(msg.content, msg.attachments, used_document_names: @used_document_names)
            cache_boundary?(msg, caching:) ? blocks + [converse_cache_block_for(caching, ttl: msg.cache_ttl)] : blocks
          end
        end

        def cache_boundary?(message, caching: nil)
          caching != false && message.cache_until_here?
        end

        # Bedrock's own caching of Claude and Nova prompts is best effort, so
        # with caching on RubyLLM places explicit points: at the end of the
        # conversation, so the next tool round or question can read what was
        # sent so far; after the system prompt (or the tools without one),
        # which stays cached when a later message changes; and after the
        # previous assistant message, because Bedrock looks for an earlier
        # cache entry only about 20 content blocks back from each point, and
        # a round of parallel tool calls can be longer than that. Points the
        # messages already mark count toward the limit of four, and an
        # automatic point never puts a shorter lifetime before a longer one,
        # which Bedrock refuses.
        def add_automatic_cache_points(payload, model, caching)
          return unless caching && automatic_cache_points?(model)

          budget = MAX_CACHE_POINTS - cache_points(payload).size
          automatic_cache_targets(payload, model).each do |blocks|
            index = automatic_cache_point_index(blocks)
            next unless index
            break if budget <= 0

            blocks.insert(index, converse_cache_block_for(caching))
            next blocks.delete_at(index) unless cache_lifetimes_descend?(payload)

            budget -= 1
          end
        end

        # Claude refuses a cache point right after an Office document, so the
        # point goes after the last block that takes one.
        def automatic_cache_point_index(blocks)
          last = blocks.rindex { |block| !office_document?(block) }
          last + 1 if last && !cache_point?(blocks[last])
        end

        def office_document?(block)
          block.is_a?(Hash) && OFFICE_DOCUMENT_FORMATS.include?(block.dig(:document, :format))
        end

        def search_results?(model)
          model_id = foundation_model_id(model&.id)
          SEARCH_RESULT_MODELS.any? { |prefix| model_id.start_with?(prefix) }
        end

        def automatic_cache_points?(model)
          model_id = foundation_model_id(model&.id)
          # An application inference profile ARN does not name its model.
          CACHE_POINT_MODELS.any? { |prefix| model_id.start_with?(prefix) } || !model_id.include?('.')
        end

        def automatic_cache_targets(payload, model)
          messages = payload[:messages]
          earlier_answer = messages[0...-1].reverse.find { |message| message[:role] == 'assistant' }

          [messages.last&.dig(:content), stable_prefix_blocks(payload, model), earlier_answer&.dig(:content)].compact
        end

        def stable_prefix_blocks(payload, model)
          return payload[:system] if payload[:system]

          tools = payload.dig(:toolConfig, :tools)
          tools if tools && TOOL_CACHE_POINT_MODELS.any? { |prefix| foundation_model_id(model&.id).start_with?(prefix) }
        end

        # In the order Bedrock reads them: tools, system, then messages.
        def cache_points(payload)
          blocks = Array(payload.dig(:toolConfig, :tools)) + Array(payload[:system]) +
                   payload[:messages].flat_map { |message| message[:content] }
          blocks.select { |block| cache_point?(block) }
        end

        def cache_lifetimes_descend?(payload)
          lifetimes = cache_points(payload).map { |block| cache_lifetime(block[:cachePoint] || block['cachePoint']) }
          lifetimes.each_cons(2).all? { |earlier, later| earlier >= later }
        end

        def cache_lifetime(point)
          ttl = point.is_a?(Hash) ? (point[:ttl] || point['ttl']) : nil
          amount, unit = ttl.to_s.match(/\A(\d+)([smh])\z/)&.captures
          amount ? amount.to_i * CACHE_LIFETIME_UNITS.fetch(unit) : 300
        end

        def cache_point?(block)
          block.is_a?(Hash) && (block.key?(:cachePoint) || block.key?('cachePoint'))
        end

        def converse_cache_block_for(caching, ttl: nil)
          options = prompt_cache_options(caching)
          ttl ||= options[:ttl]
          point = { type: 'default' }
          point[:ttl] = ttl if ttl
          { cachePoint: point }
        end

        def prompt_cache_options(caching)
          return {} unless caching

          options = caching.to_h.transform_keys(&:to_sym)
          unsupported = options.keys - PROMPT_CACHE_OPTIONS
          return options if unsupported.empty?

          raise ArgumentError,
                "Bedrock Converse prompt caching accepts :ttl, got #{format_cache_option_keys(unsupported)}"
        end

        def format_cache_option_keys(keys)
          keys.map { |key| ":#{key}" }.join(', ')
        end

        def render_inference_config(_model, temperature, max_output_tokens = nil)
          config = {}
          config[:temperature] = temperature unless temperature.nil?
          config[:maxTokens] = max_output_tokens unless max_output_tokens.nil?
          config
        end

        def render_tool_config(tools, tool_prefs)
          return nil if tools.empty?

          config = {
            tools: tools.values.map { |tool| render_tool(tool) }
          }

          return config if tool_prefs.nil? || tool_prefs[:choice].nil?

          tool_choice = render_tool_choice(tool_prefs[:choice])
          config[:toolChoice] = tool_choice if tool_choice
          config
        end

        def render_tool_choice(choice)
          case choice
          when :auto
            { auto: {} }
          when :none
            nil
          when :required
            { any: {} }
          else
            { tool: { name: choice.to_s } }
          end
        end

        def render_tool(tool)
          input_schema = tool.parameters_schema ||
                         RubyLLM::Tool::SchemaDefinition.from_parameters(tool.declared_parameters)&.json_schema

          tool_spec = {
            toolSpec: {
              name: tool.name,
              description: tool.description,
              inputSchema: {
                json: input_schema || default_input_schema
              }
            }
          }

          return tool_spec if tool.provider_options.empty?

          RubyLLM::Support::Utils.deep_merge(tool_spec, tool.provider_options)
        end

        def render_additional_model_request_fields(thinking, model, max_output_tokens = nil)
          fields = {}

          reasoning_fields = Reasoning.render_reasoning_fields(thinking, model, max_output_tokens)
          fields = RubyLLM::Support::Utils.deep_merge(fields, reasoning_fields) if reasoning_fields

          fields.empty? ? nil : fields
        end

        def bind_replayed_thinking(fields, messages, model)
          return fields unless Anthropic::BlockBinding.binds?(foundation_model_id(model&.id))
          return fields if fields&.key?(:reasoning_config) || !replays_thinking?(messages)

          bound = Anthropic::BlockBinding.apply(fields&.dig(:thinking))
          bound ? { **fields.to_h, thinking: bound, anthropic_beta: [Anthropic::BlockBinding::BETA] } : fields
        end

        def replays_thinking?(messages)
          messages.any? do |message|
            message[:content].any? { |block| block.key?(:reasoningContent) || block.key?('reasoningContent') }
          end
        end

        def build_output_config(schema)
          return nil unless schema

          cleaned = RubyLLM::Support::Utils.deep_dup(schema[:schema])
          cleaned.delete(:strict)
          cleaned.delete('strict')

          {
            textFormat: {
              type: 'json_schema',
              structure: {
                jsonSchema: {
                  schema: JSON.generate(cleaned),
                  name: schema[:name]
                }
              }
            }
          }
        end

        # Inference profile and foundation model ARNs name the model in their last segment.
        def foundation_model_id(model_id)
          prefixes = Converse::REGION_PREFIXES.join('|')
          model_id.to_s.rpartition('/').last.sub(/\A(?:#{prefixes})\./, '')
        end

        def render_thinking_block(thinking)
          return nil unless thinking

          if thinking.text
            {
              reasoningContent: {
                reasoningText: {
                  text: thinking.text,
                  signature: thinking.signature
                }.compact
              }
            }
          elsif thinking.signature
            {
              reasoningContent: {
                redactedContent: thinking.signature
              }
            }
          end
        end

        def parse_text_and_citations(content_blocks)
          text = +''
          citations = []

          content_blocks.each do |block|
            if block['text'].is_a?(String)
              text << block['text']
            elsif block['citationsContent'].is_a?(Hash)
              append_citations_content(block['citationsContent'], text, citations)
            end
          end

          [text.empty? ? nil : text, citations]
        end

        # A citationsContent block replaces the text block for a cited span:
        # the generated text lives in its content member, and each citation
        # points back at the source document or search result.
        def append_citations_content(citations_content, text, citations)
          block_text = joined_text(citations_content['content'])
          span = {}
          unless block_text.empty?
            span = { text: block_text, start_index: text.length, end_index: text.length + block_text.length }
          end

          Array(citations_content['citations']).each do |citation|
            citations << parse_citation(citation, **span)
          end
          text << block_text
        end

        def parse_citation(data, text: nil, start_index: nil, end_index: nil)
          location = data['location'] || {}
          page = location['documentPage'] || {}
          end_page = page['end']
          cited_text = joined_text(data['sourceContent'])

          Citation.new(
            url: citation_url(data, location),
            title: data['title'],
            cited_text: cited_text.empty? ? nil : cited_text,
            text: text,
            start_index: start_index,
            end_index: end_index,
            source_id: data['source'],
            source_index: citation_source_index(location),
            start_page: page['start'],
            end_page: end_page && (end_page - 1)
          )
        end

        def joined_text(parts)
          Array(parts).filter_map { |part| part['text'] if part.is_a?(Hash) }.join
        end

        # Search result citations carry the developer-provided source string.
        def citation_url(data, location)
          url = location.dig('web', 'url') || data['source']
          url if url&.match?(%r{\Ahttps?://}i)
        end

        def citation_source_index(location)
          %w[documentChar documentPage documentChunk].each do |key|
            index = location.dig(key, 'documentIndex')
            return index if index
          end

          location.dig('searchResultLocation', 'searchResultIndex')
        end

        def parse_thinking(content_blocks)
          text = nil
          signature = nil

          content_blocks.each do |block|
            chunk_text, chunk_signature = parse_reasoning_content_block(block)
            if chunk_text
              text ||= +''
              text << chunk_text
            end
            signature ||= chunk_signature
          end

          [text, signature]
        end

        def parse_thinking_blocks(content_blocks)
          blocks = content_blocks.select { |block| block['reasoningContent'].is_a?(Hash) }
          { 'converse' => blocks } unless blocks.empty?
        end

        def parse_reasoning_content_block(block)
          reasoning_content = block['reasoningContent']
          return [nil, nil] unless reasoning_content.is_a?(Hash)

          reasoning_text = reasoning_content['reasoningText'] || {}
          text = reasoning_text['text'].is_a?(String) ? reasoning_text['text'] : nil
          signature = reasoning_text['signature'] if reasoning_text['signature'].is_a?(String)
          signature ||= reasoning_content['redactedContent'] if reasoning_content['redactedContent'].is_a?(String)
          [text, signature]
        end

        def parse_tool_calls(content_blocks)
          calls = content_blocks.filter_map do |block|
            tool_use = block['toolUse']
            next unless tool_use
            next if server_tool_use?(tool_use)

            ToolCall.new(
              provider_call_id: tool_use['toolUseId'],
              name: tool_use['name'],
              arguments: tool_use['input'] || {}
            )
          end

          ToolCall.index(calls, by: :provider_call_id) unless calls.empty?
        end

        # Provider-executed tool steps come back with a distinguishing type,
        # such as server_tool_use; function calls carry no type or the plain
        # tool_use type.
        def server_tool_use?(tool_use)
          type = tool_use['type']
          !type.nil? && type != 'tool_use'
        end

        def server_tool_result?(tool_result)
          type = tool_result['type']
          !type.nil? && type != 'tool_result'
        end

        def parse_server_tool_calls(content_blocks)
          content_blocks.filter_map do |block|
            tool_use = block['toolUse']
            tool_result = block['toolResult']

            if tool_use && server_tool_use?(tool_use)
              ServerToolCall.new(type: tool_use['type'], name: tool_use['name'], id: tool_use['toolUseId'],
                                 input: tool_use['input'], raw: block)
            elsif tool_result && server_tool_result?(tool_result)
              ServerToolCall.new(type: tool_result['type'], id: tool_result['toolUseId'],
                                 result: tool_result['content'], raw: block)
            end
          end
        end

        def default_input_schema
          {
            'type' => 'object',
            'properties' => {},
            'required' => []
          }
        end
      end
    end
  end
end
