# frozen_string_literal: true

require 'json'

module RubyLLM
  module Protocols
    class Converse
      # Chat methods for Bedrock Converse API.
      module Chat
        BEDROCK_INLINE_DOCUMENT_LIMIT = 4_500_000
        PROMPT_CACHE_OPTIONS = %i[ttl].freeze

        module_function

        def completion_url
          "/model/#{@model.id}/converse"
        end

        # rubocop:disable Metrics/ParameterLists,Lint/UnusedMethodArgument
        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil,
                           schema: nil, thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          warn_unsupported_citations(model) if citations
          tool_prefs ||= {}
          @used_document_names = {}
          system_messages, chat_messages = messages.partition { |msg| msg.role == :system }
          prompt_cache_options(caching)
          automatic_cache_target = automatic_cache_target(system_messages, chat_messages, caching)
          payload = {
            messages: format_messages(chat_messages, caching:, automatic_cache_target:)
          }

          system_blocks = format_system(system_messages, caching:, automatic_cache_target:)
          payload[:system] = system_blocks unless system_blocks.empty?

          payload[:inferenceConfig] = format_inference_config(model, temperature, max_output_tokens)

          tool_config = format_tool_config(tools, tool_prefs)
          payload[:toolConfig] = tool_config if tool_config

          additional_fields = format_additional_model_request_fields(thinking)
          payload[:additionalModelRequestFields] = additional_fields if additional_fields

          output_config = build_output_config(schema)
          payload[:outputConfig] = output_config if output_config

          payload
        end
        # rubocop:enable Metrics/ParameterLists,Lint/UnusedMethodArgument

        def warn_unsupported_citations(model)
          RubyLLM.logger.warn(
            "RubyLLM does not support citations on Bedrock yet. Ignoring with_citations for #{model.id}."
          )
        end

        def supports_provider_file_references?
          true
        end

        def default_large_file_upload_threshold
          BEDROCK_INLINE_DOCUMENT_LIMIT
        end

        def provider_file_attachable?(attachment)
          attachment.pdf? || attachment.document? || attachment.text?
        end

        def parse_completion_body(data, raw:)
          content_blocks = data.dig('output', 'message', 'content') || []
          usage = data['usage'] || {}
          thinking_text, thinking_signature = parse_thinking(content_blocks)

          Message.new(
            role: :assistant,
            content: parse_text_content(content_blocks),
            thinking: Thinking.build(text: thinking_text, signature: thinking_signature),
            tool_calls: parse_tool_calls(content_blocks),
            input_tokens: input_tokens(usage),
            output_tokens: usage['outputTokens'],
            cache_read_tokens: usage['cacheReadInputTokens'],
            cache_write_tokens: usage['cacheWriteInputTokens'],
            thinking_tokens: reasoning_tokens(usage),
            finish_reason: data['stopReason'],
            model: data['modelId'],
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

        def format_messages(messages, caching: nil, automatic_cache_target: nil)
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

            message = format_non_tool_message(msg, caching:, automatic_cache_target:)
            rendered << message if message
          end

          rendered << { role: 'user', content: tool_result_blocks } unless tool_result_blocks.empty?
          rendered
        end

        def format_non_tool_message(msg, caching: nil, automatic_cache_target: nil)
          content = format_message_content(msg, caching:, automatic_cache_target:)
          return nil if content.empty?

          {
            role: format_role(msg.role),
            content: content
          }
        end

        def format_message_content(msg, caching: nil, automatic_cache_target: nil)
          blocks = format_structured_message_content(msg)

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
          blocks << converse_cache_block_for(caching) if cache_boundary?(msg, automatic_cache_target)

          blocks
        end

        def format_structured_message_content(msg)
          blocks = []

          thinking_block = format_thinking_block(msg.thinking)
          blocks << thinking_block if msg.role == :assistant && thinking_block

          blocks.concat(Media.format_content(msg.content, msg.attachments, used_document_names: @used_document_names))

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
          blocks = Media.format_content(msg.content, msg.attachments, used_document_names: @used_document_names)
          blocks.empty? ? [text_tool_result_block(nil)] : blocks
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
            cache_boundary?(msg, automatic_cache_target) ? blocks + [converse_cache_block_for(caching)] : blocks
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

        def cache_boundary?(message, automatic_cache_target)
          message.cache_until_here? || message.equal?(automatic_cache_target)
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

        def format_additional_model_request_fields(thinking)
          fields = {}

          reasoning_fields = format_reasoning_fields(thinking)
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

        def format_reasoning_fields(thinking)
          return nil unless thinking&.enabled?

          effort_config = effort_reasoning_config(thinking)
          return effort_config if effort_config

          budget_reasoning_config(thinking)
        end

        def effort_reasoning_config(thinking)
          effort = thinking.effort.to_s
          return nil if effort.empty? || effort == 'none'

          if Converse.reasoning_embedded?(@model)
            { reasoning_config: { type: 'enabled', reasoning_effort: effort } }
          else
            { reasoning_effort: effort }
          end
        end

        def budget_reasoning_config(thinking)
          budget = thinking.budget
          return nil unless budget.is_a?(Integer)

          { reasoning_config: { type: 'enabled', budget_tokens: budget } }
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

        def parse_text_content(content_blocks)
          text = content_blocks.filter_map { |block| block['text'] if block['text'].is_a?(String) }.join
          text.empty? ? nil : text
        end

        def parse_thinking(content_blocks)
          text = +''
          signature = nil

          content_blocks.each do |block|
            chunk_text, chunk_signature = parse_reasoning_content_block(block)
            text << chunk_text if chunk_text
            signature ||= chunk_signature
          end

          [text.empty? ? nil : text, signature]
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

            tool_call_id = tool_use['toolUseId']
            tool_calls[tool_call_id] = ToolCall.new(
              id: tool_call_id,
              name: tool_use['name'],
              arguments: tool_use['input'] || {}
            )
          end

          tool_calls.empty? ? nil : tool_calls
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
