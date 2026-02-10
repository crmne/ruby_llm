# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Chat methods for Bedrock Converse API.
      module Chat
        module_function

        def completion_url
          "/model/#{@model.id}/converse"
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil, thinking: nil) # rubocop:disable Metrics/ParameterLists,Lint/UnusedMethodArgument
          @model = model
          @used_document_names = {}
          system_messages, chat_messages = messages.partition { |msg| msg.role == :system }

          payload = {
            messages: render_messages(chat_messages)
          }

          system_blocks = render_system(system_messages)
          payload[:system] = system_blocks unless system_blocks.empty?

          payload[:inferenceConfig] = render_inference_config(model, temperature)

          tool_config = render_tool_config(tools)
          if tool_config
            payload[:toolConfig] = tool_config
            payload[:tools] = tool_config[:tools] # Internal mirror for shared payload inspections in specs.
          end

          additional_fields = render_additional_model_request_fields(thinking)
          payload[:additionalModelRequestFields] = additional_fields if additional_fields

          payload
        end

        def parse_completion_response(response)
          data = response.body
          return if data.nil? || data.empty?

          content_blocks = data.dig('output', 'message', 'content') || []
          usage = data['usage'] || {}
          thinking_text, thinking_signature = parse_thinking(content_blocks)

          Message.new(
            role: :assistant,
            content: parse_text_content(content_blocks),
            thinking: Thinking.build(text: thinking_text, signature: thinking_signature),
            tool_calls: parse_tool_calls(content_blocks),
            input_tokens: usage['inputTokens'],
            output_tokens: usage['outputTokens'],
            cached_tokens: usage['cacheReadInputTokens'],
            cache_creation_tokens: usage['cacheWriteInputTokens'],
            thinking_tokens: usage['reasoningTokens'],
            model_id: data['modelId'],
            raw: response
          )
        end

        def render_messages(messages)
          rendered = []
          tool_result_blocks = []

          messages.each do |msg|
            if msg.tool_result?
              tool_result_blocks << render_tool_result_block(msg)
              next
            end

            unless tool_result_blocks.empty?
              rendered << { role: 'user', content: tool_result_blocks }
              tool_result_blocks = []
            end

            message = render_non_tool_message(msg)
            rendered << message if message
          end

          rendered << { role: 'user', content: tool_result_blocks } unless tool_result_blocks.empty?
          rendered
        end

        def render_non_tool_message(msg)
          content = render_message_content(msg)
          return nil if content.empty?

          {
            role: render_role(msg.role),
            content: content
          }
        end

        def render_message_content(msg)
          if msg.content.is_a?(RubyLLM::Content::Raw)
            return render_raw_content(msg.content) if msg.role == :assistant

            return sanitize_non_assistant_raw_blocks(render_raw_content(msg.content))
          end

          blocks = []

          thinking_block = render_thinking_block(msg.thinking)
          blocks << thinking_block if msg.role == :assistant && thinking_block

          text_and_media_blocks = Media.render_content(msg.content, used_document_names: @used_document_names)
          blocks.concat(text_and_media_blocks) if text_and_media_blocks

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

          blocks
        end

        def render_raw_content(content)
          value = content.value
          value.is_a?(Array) ? value : [value]
        end

        def sanitize_non_assistant_raw_blocks(blocks)
          blocks.filter_map do |block|
            next unless block.is_a?(Hash)
            next if block.key?(:reasoningContent) || block.key?('reasoningContent')

            block
          end
        end

        def render_tool_result_block(msg)
          {
            toolResult: {
              toolUseId: msg.tool_call_id,
              content: render_tool_result_content(msg.content)
            }
          }
        end

        def render_tool_result_content(content)
          return render_raw_tool_result_content(content.value) if content.is_a?(RubyLLM::Content::Raw)

          if content.is_a?(Hash) || content.is_a?(Array)
            [{ json: content }]
          elsif content.is_a?(RubyLLM::Content)
            blocks = []
            blocks << { text: content.text } if content.text
            content.attachments.each do |attachment|
              blocks << { text: attachment.for_llm }
            end
            blocks
          else
            [{ text: content.to_s }]
          end
        end

        def render_raw_tool_result_content(raw_value)
          blocks = raw_value.is_a?(Array) ? raw_value : [raw_value]

          normalized = blocks.filter_map do |block|
            normalize_tool_result_block(block)
          end

          normalized.empty? ? [{ text: raw_value.to_s }] : normalized
        end

        def normalize_tool_result_block(block)
          return nil unless block.is_a?(Hash)
          return block if tool_result_content_block?(block)

          nil
        end

        def tool_result_content_block?(block)
          %w[text json document image].any? do |key|
            block.key?(key) || block.key?(key.to_sym)
          end
        end

        def render_role(role)
          case role
          when :assistant then 'assistant'
          else 'user'
          end
        end

        def render_system(messages)
          messages.flat_map { |msg| Media.render_content(msg.content, used_document_names: @used_document_names) }
        end

        def render_inference_config(_model, temperature)
          config = {}
          config[:temperature] = temperature unless temperature.nil?
          config
        end

        def render_tool_config(tools)
          return nil if tools.empty?

          {
            tools: tools.values.map { |tool| render_tool(tool) }
          }
        end

        def render_tool(tool)
          input_schema = tool.params_schema || RubyLLM::Tool::SchemaDefinition.from_parameters(tool.parameters)&.json_schema

          tool_spec = {
            toolSpec: {
              name: tool.name,
              description: tool.description,
              inputSchema: {
                json: input_schema || default_input_schema
              }
            }
          }

          return tool_spec if tool.provider_params.empty?

          RubyLLM::Utils.deep_merge(tool_spec, tool.provider_params)
        end

        def render_additional_model_request_fields(thinking)
          fields = {}

          reasoning_fields = render_reasoning_fields(thinking)
          fields = RubyLLM::Utils.deep_merge(fields, reasoning_fields) if reasoning_fields

          fields.empty? ? nil : fields
        end

        def render_reasoning_fields(thinking)
          return nil unless thinking&.enabled?

          effort_config = effort_reasoning_config(thinking)
          return effort_config if effort_config

          budget_reasoning_config(thinking)
        end

        def effort_reasoning_config(thinking)
          effort = thinking.respond_to?(:effort) ? thinking.effort : nil
          effort = effort.to_s if effort
          return nil if effort.nil? || effort.empty? || effort == 'none'

          if reasoning_embedded?(@model)
            { reasoning_config: { type: 'enabled', reasoning_effort: effort } }
          else
            { reasoning_effort: effort }
          end
        end

        def budget_reasoning_config(thinking)
          budget = thinking.respond_to?(:budget) ? thinking.budget : thinking
          return nil unless budget.is_a?(Integer)

          { reasoning_config: { type: 'enabled', budget_tokens: budget } }
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
