# frozen_string_literal: true

require 'json'

module RubyLLM
  module Protocols
    class Converse
      # Chat methods for Bedrock Converse API.
      module Chat
        FINISH_REASONS = {
          'end_turn' => 'stop', 'stop_sequence' => 'stop', 'max_tokens' => 'max_tokens',
          'model_context_window_exceeded' => 'max_tokens', 'tool_use' => 'tool_calls',
          'guardrail_intervened' => 'content_filter', 'content_filtered' => 'content_filter'
        }.freeze

        BEDROCK_INLINE_DOCUMENT_LIMIT = 4_500_000
        PROMPT_CACHE_OPTIONS = %i[ttl].freeze
        COUNT_TOKENS_KEYS = %i[messages system toolConfig additionalModelRequestFields].freeze
        RANGED_EFFORTS = %w[low medium high].freeze
        MINIMUM_BUDGET_TOKENS = 1

        module_function

        def finish_reasons = FINISH_REASONS

        def normalize_finish_reason(reason)
          return nil if reason.nil?

          finish_reasons.fetch(reason.to_s, reason)
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
          @used_document_names = {}
          system_messages, chat_messages = messages.partition { |msg| msg.role == :system }
          prompt_cache_options(caching)
          automatic_cache_target = automatic_cache_target(system_messages, chat_messages, caching)
          payload = {
            messages: format_messages(chat_messages, caching:, automatic_cache_target:, citations:)
          }

          system_blocks = format_system(system_messages, caching:, automatic_cache_target:)
          payload[:system] = system_blocks unless system_blocks.empty?

          payload[:inferenceConfig] = format_inference_config(model, temperature, max_output_tokens)

          tool_config = format_tool_config(tools, tool_prefs)
          payload[:toolConfig] = tool_config if tool_config

          additional_fields = format_additional_model_request_fields(thinking, model, max_output_tokens)
          payload[:additionalModelRequestFields] = additional_fields if additional_fields

          output_config = build_output_config(schema)
          payload[:outputConfig] = output_config if output_config

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

        def supports_provider_file_references?
          true
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
          text_content, citations = extract_text_and_citations(content_blocks)

          Message.new(
            role: :assistant,
            content: text_content,
            citations: citations,
            thinking: Thinking.build(text: thinking_text, signature: thinking_signature),
            tool_calls: parse_tool_calls(content_blocks),
            server_tool_calls: extract_server_tool_calls(content_blocks),
            input_tokens: input_tokens(usage),
            output_tokens: usage['outputTokens'],
            cache_read_tokens: usage['cacheReadInputTokens'],
            cache_write_tokens: usage['cacheWriteInputTokens'],
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

        def format_messages(messages, caching: nil, automatic_cache_target: nil, citations: false)
          rendered = []
          tool_result_blocks = []

          messages.each do |msg|
            if msg.tool_result?
              tool_result_blocks << format_tool_result_block(msg)
              next
            end

            unless tool_result_blocks.empty?
              rendered << { role: 'user', content: tool_result_blocks }
              tool_result_blocks = []
            end

            message = format_non_tool_message(msg, caching:, automatic_cache_target:, citations:)
            rendered << message if message
          end

          rendered << { role: 'user', content: tool_result_blocks } unless tool_result_blocks.empty?
          rendered
        end

        def format_non_tool_message(msg, caching: nil, automatic_cache_target: nil, citations: false)
          content = format_message_content(msg, caching:, automatic_cache_target:, citations:)
          return nil if content.empty?

          {
            role: format_role(msg.role),
            content: content
          }
        end

        def format_message_content(msg, caching: nil, automatic_cache_target: nil, citations: false)
          blocks = format_structured_message_content(msg, citations:)

          if msg.tool_call?
            msg.tool_calls.each_value do |tool_call|
              blocks << {
                toolUse: {
                  toolUseId: tool_call.id,
                  name: tool_call.name,
                  input: tool_call.arguments
                }
              }
            end
          end
          blocks << converse_cache_block_for(caching) if cache_boundary?(msg, automatic_cache_target, caching:)

          blocks
        end

        def format_structured_message_content(msg, citations: false)
          blocks = []

          thinking_block = format_thinking_block(msg.thinking)
          blocks << thinking_block if msg.role == :assistant && thinking_block

          blocks.concat(
            Media.format_content(msg.content, msg.attachments, used_document_names: @used_document_names, citations:)
          )

          blocks
        end

        def format_tool_result_block(msg)
          {
            toolResult: {
              toolUseId: msg.tool_call_id,
              content: format_tool_result_content(msg)
            }
          }
        end

        def format_tool_result_content(msg)
          search_results = RubyLLM::SearchResults.from_content(msg.content)
          return search_results.results.map { |result| search_result_block(result) } if search_results

          blocks = Media.format_content(msg.content, msg.attachments, used_document_names: @used_document_names)
          blocks.empty? ? [text_tool_result_block(nil)] : blocks
        end

        def search_result_block(result)
          {
            searchResult: {
              source: result[:url] || result[:title],
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

        def format_role(role)
          case role
          when :assistant then 'assistant'
          else 'user'
          end
        end

        def format_system(messages, caching: nil, automatic_cache_target: nil)
          messages.flat_map do |msg|
            blocks = Media.format_content(msg.content, msg.attachments, used_document_names: @used_document_names)
            if cache_boundary?(msg, automatic_cache_target, caching:)
              blocks + [converse_cache_block_for(caching)]
            else
              blocks
            end
          end
        end

        def automatic_cache_target(system_messages, chat_messages, caching)
          return unless caching
          return if (system_messages + chat_messages).any?(&:cache_until_here?)

          (chat_messages.reverse + system_messages.reverse).find { |msg| cacheable_message?(msg) }
        end

        def cacheable_message?(message)
          !message.tool_result?
        end

        def cache_boundary?(message, automatic_cache_target, caching: nil)
          caching != false && (message.cache_until_here? || message.equal?(automatic_cache_target))
        end

        def converse_cache_block_for(caching)
          options = prompt_cache_options(caching)
          point = { type: 'default' }
          point[:ttl] = options[:ttl] if options[:ttl]
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

        def format_inference_config(_model, temperature, max_output_tokens = nil)
          config = {}
          config[:temperature] = temperature unless temperature.nil?
          config[:maxTokens] = max_output_tokens unless max_output_tokens.nil?
          config
        end

        def format_tool_config(tools, tool_prefs)
          return nil if tools.empty?

          config = {
            tools: tools.values.map { |tool| format_tool(tool) }
          }

          return config if tool_prefs.nil? || tool_prefs[:choice].nil?

          tool_choice = format_tool_choice(tool_prefs[:choice])
          config[:toolChoice] = tool_choice if tool_choice
          config
        end

        def format_tool_choice(choice)
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

        def format_tool(tool)
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

          RubyLLM::Utils.deep_merge(tool_spec, tool.provider_options)
        end

        def format_additional_model_request_fields(thinking, model, max_output_tokens = nil)
          fields = {}

          reasoning_fields = format_reasoning_fields(thinking, model, max_output_tokens)
          fields = RubyLLM::Utils.deep_merge(fields, reasoning_fields) if reasoning_fields

          fields.empty? ? nil : fields
        end

        def build_output_config(schema)
          return nil unless schema

          cleaned = RubyLLM::Utils.deep_dup(schema[:schema])
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

        NOVA_DEFAULT_REASONING_EFFORT = 'low'

        def format_reasoning_fields(thinking, model, max_output_tokens = nil)
          return nil unless thinking&.enabled?
          return format_nova_reasoning_fields(thinking, model) if nova_model?(model)
          return { reasoning_config: { type: 'disabled' } } if thinking.enabled == false

          effort = thinking.effort.to_s
          budget = reasoning_budget(thinking, effort, model, max_output_tokens)
          return { reasoning_config: { type: 'enabled', budget_tokens: budget } } if budget
          return nil if effort.empty? || effort == 'none'

          { reasoning_effort: effort }
        end

        def nova_model?(model)
          foundation_model_id(model&.id).start_with?('amazon.nova')
        end

        # Nova 2 takes reasoningConfig with an effort level instead of a token budget,
        # and rejects an enabled reasoningConfig that names no effort.
        def format_nova_reasoning_fields(thinking, model)
          if thinking.budget
            raise ArgumentError,
                  "#{model&.id} takes a reasoning effort, not a token budget of #{thinking.budget}. " \
                  'Pass with_thinking(effort:) instead.'
          end

          return { reasoningConfig: { type: 'disabled' } } if thinking.enabled == false

          effort = thinking.effort.to_s
          return nil if effort == 'none'

          effort = NOVA_DEFAULT_REASONING_EFFORT if effort.empty?
          { reasoningConfig: { type: 'enabled', maxReasoningEffort: effort } }
        end

        def reasoning_budget(thinking, effort, model, max_output_tokens)
          return thinking.budget if thinking.budget.is_a?(Integer)
          return nil if effort.empty? || effort == 'none'

          schema = reasoning_budget_schema(model)
          schema && effort_budget_tokens(effort, schema, model, max_output_tokens)
        end

        # Bedrock only publishes Converse metadata for some regional entries, so use the
        # schema from another entry for the same foundation model when needed.
        def reasoning_budget_schema(model)
          schema = budget_tokens_schema(model)
          return schema if schema
          return unless model

          foundation_id = foundation_model_id(model.id)
          RubyLLM.models.all.each do |candidate|
            next unless candidate.provider == 'bedrock' && candidate.id != model.id
            next unless foundation_model_id(candidate.id) == foundation_id

            return schema if (schema = budget_tokens_schema(candidate))
          end

          nil
        end

        def budget_tokens_schema(model)
          metadata = RubyLLM::Utils.deep_symbolize_keys(model&.metadata || {})
          raw_schema = metadata.dig(:converse, :additionalRequestFieldsSchema)
          return unless raw_schema.is_a?(String)

          schema = JSON.parse(raw_schema, symbolize_names: true)
          budget = schema.is_a?(Hash) ? schema.dig(:reasoningConfig, :budgetTokens) : nil
          budget if budget.is_a?(Hash)
        rescue JSON::ParserError
          nil
        end

        # Inference profile and foundation model ARNs name the model in their last segment.
        def foundation_model_id(model_id)
          prefixes = Converse::REGION_PREFIXES.join('|')
          model_id.to_s.rpartition('/').last.sub(/\A(?:#{prefixes})\./, '')
        end

        # Models that take a budget reject reasoning_effort, so effort has to become a budget.
        # Bedrock names the levels of an enumerated budget after the efforts they stand for;
        # otherwise the effort spans the range the schema allows.
        def effort_budget_tokens(effort, schema, model, max_output_tokens)
          budget = enumerated_budget(effort, schema) || ranged_budget(effort, schema)
          return nil unless budget

          minimum = schema[:minimum].is_a?(Integer) ? schema[:minimum] : MINIMUM_BUDGET_TOKENS
          return [budget, minimum].max unless max_output_tokens

          budget.clamp(minimum, budget_ceiling(model, minimum, max_output_tokens))
        end

        # Bedrock rejects a budget that leaves no room for the answer.
        def budget_ceiling(model, minimum, max_output_tokens)
          ceiling = max_output_tokens - 1
          return ceiling if minimum <= ceiling

          raise ArgumentError, "#{model&.id} reasons on a budget of at least #{minimum} tokens, and " \
                               "max_output_tokens: #{max_output_tokens} leaves room for #{ceiling}. " \
                               "Raise max_output_tokens above #{minimum} or turn thinking off."
        end

        def enumerated_budget(effort, schema)
          levels = schema[:enum]
          level = levels.is_a?(Hash) ? levels[effort.to_sym] : nil
          level if level.is_a?(Integer)
        end

        def ranged_budget(effort, schema)
          minimum = schema[:minimum]
          maximum = schema[:maximum]
          return nil unless minimum.is_a?(Integer) && maximum.is_a?(Integer)

          case effort
          when 'low' then minimum
          when 'medium' then minimum + ((maximum - minimum) / 2)
          when 'high' then maximum
          else raise ArgumentError, unknown_effort_message(effort, schema)
          end
        end

        def unknown_effort_message(effort, schema)
          levels = schema[:enum].is_a?(Hash) ? schema[:enum].keys.map(&:to_s) : []
          levels |= RANGED_EFFORTS
          "Bedrock has no reasoning budget for effort #{effort.inspect}. " \
            "Use #{levels.join(', ')}, or pass an explicit budget."
        end

        def format_thinking_block(thinking)
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

        def extract_text_and_citations(content_blocks)
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
          tool_calls = {}

          content_blocks.each do |block|
            tool_use = block['toolUse']
            next unless tool_use
            next if server_tool_use?(tool_use)

            tool_call_id = tool_use['toolUseId']
            tool_calls[tool_call_id] = ToolCall.new(
              id: tool_call_id,
              name: tool_use['name'],
              arguments: tool_use['input'] || {}
            )
          end

          tool_calls.empty? ? nil : tool_calls
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

        def extract_server_tool_calls(content_blocks)
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
