# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Chat methods for the AWS Bedrock API implementation
      module Chat
        module_function

        def completion_url
          "model/#{@model_id}/converse"
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil) # rubocop:disable Lint/UnusedMethodArgument,Metrics/ParameterLists
          @model_id = model.id

          system_messages, chat_messages = messages.partition { |msg| msg.role == :system }
          system_content = build_system_content(system_messages)

          build_base_payload(chat_messages, model).tap do |p|
            add_optional_fields(p, system_content:, tools:, temperature:)
          end
        end

        def format_message(msg)
          if msg.tool_call?
            result = Tools.format_tool_call(msg, role: format_role(msg.role))
            # If format_tool_call returns nil (due to missing tool_call), skip this message
            return nil if result.nil?

            result
          elsif msg.tool_result?
            result = Tools.format_tool_result(msg, role: format_role(msg.role))
            # If format_tool_result returns nil (due to missing tool_call_id), skip this message
            return nil if result.nil?

            result
          else
            {
              role: format_role(msg.role),
              content: Media.format_content(msg.content)
            }
          end
        end

        def format_role(role)
          case role
          when :system, :user, :tool then 'user'
          else 'assistant'
          end
        end

        def parse_completion_response(response)
          data = response.body
          RubyLLM.logger.debug "Parsing Bedrock response data: #{data}" if RubyLLM.config.log_stream_debug

          output = data['output'] || {}
          message = output['message'] || {}
          content_blocks = message['content'] || []
          text_content = extract_text_content(content_blocks)
          tool_use_blocks = Tools.find_tool_uses(content_blocks)

          build_message(data, text_content, tool_use_blocks, response)
        end

        def extract_text_content(blocks)
          text_blocks = blocks.select { |c| c['text'] }
          text_blocks.map { |c| c['text'] }.join
        end

        def build_message(data, content, tool_use_blocks, response)
          # Validate required fields
          if content.nil?
            RubyLLM.logger.warn 'Bedrock: content is nil, setting to empty string'
            content = ''
          end

          if @model_id.nil?
            RubyLLM.logger.warn 'Bedrock: model_id is nil'
            @model_id = 'unknown'
          end

          RubyLLM::Message.new(
            role: :assistant,
            content: content,
            tool_calls: Tools.parse_tool_calls(tool_use_blocks),
            input_tokens: data.dig('usage', 'inputTokens'),
            output_tokens: data.dig('usage', 'outputTokens'),
            model_id: @model_id,
            raw: response
          )
        end

        def build_system_content(system_messages)
          if system_messages.length > 1
            RubyLLM.logger.warn(
              "Bedrock's converse implementation only supports a single system message. " \
              'Multiple system messages will be combined into one.'
            )
          end

          system_messages.map(&:content).join("\n\n")
        end

        def build_base_payload(chat_messages, model)
          compacted_messages = chat_messages.filter_map { |msg| format_message(msg) }
          compacted_messages = Tools.merge_consecutive_tool_result_messages(compacted_messages)
          Tools.validate_no_tool_use_and_result!(compacted_messages)

          {
            messages: compacted_messages,
            inferenceConfig: {
              maxTokens: model.max_tokens || 4096
            }
          }
        end

        def add_optional_fields(payload, system_content:, tools:, temperature:)
          if system_content && !system_content.empty?
            # Add system message as the first user message
            payload[:messages].unshift({
                                         role: 'user',
                                         content: [{ 'text' => system_content }]
                                       })
          end

          payload[:inferenceConfig][:temperature] = temperature unless temperature.nil?

          return unless tools.any?

          payload[:toolConfig] = {
            tools: tools.values.map { |t| Tools.tool_for(t) },
            toolChoice: { auto: {} }
          }
        end
      end
    end
  end
end
