# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Chat methods for the AWS Bedrock API implementation
      module Chat
        private

        def completion_url
          "model/#{@model_id}/invoke"
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false) # rubocop:disable Lint/UnusedMethodArgument
          # Hold model_id in instance variable for use in completion_url and stream_url
          @model_id = model

          system_messages, chat_messages = separate_messages(messages)
          system_content = build_system_content(system_messages)

          build_base_payload(chat_messages, temperature, model).tap do |payload|
            add_optional_fields(payload, system_content:, tools:)
          end
        end

        def separate_messages(messages)
          messages.partition { |msg| msg.role == :system }
        end

        def build_system_content(system_messages)
          if system_messages.length > 1
            RubyLLM.logger.warn(
              "Amazon Bedrock's Claude implementation only supports a single system message. " \
              'Multiple system messages will be combined into one.'
            )
          end

          system_messages.map { |msg| format_message(msg)[:content] }.join("\n\n")
        end

        def build_base_payload(chat_messages, temperature, model)
          {
            anthropic_version: 'bedrock-2023-05-31',
            messages: chat_messages.map { |msg| format_message(msg) },
            temperature: temperature,
            max_tokens: RubyLLM.models.find(model).max_tokens
          }
        end

        def add_optional_fields(payload, system_content:, tools:)
          payload[:tools] = tools.values.map { |t| function_for(t) } if tools.any?
          payload[:system] = system_content unless system_content.empty?
        end

        def format_message(msg)
          if msg.tool_call?
            format_tool_call(msg)
          elsif msg.tool_result?
            format_tool_result(msg)
          else
            format_basic_message(msg)
          end
        end

        def format_basic_message(msg)
          {
            role: convert_role(msg.role),
            content: Anthropic::Media.format_content(msg.content)
          }
        end

        def convert_role(role)
          case role
          when :tool, :user then 'user'
          when :system then 'system'
          else 'assistant'
          end
        end

        def parse_completion_response(response)
          data = response.body
          content_blocks = data['content'] || []

          text_content = extract_text_content(content_blocks)
          tool_use = find_tool_use(content_blocks)

          build_message(data, text_content, tool_use)
        end

        def extract_text_content(blocks)
          text_blocks = blocks.select { |c| c['type'] == 'text' }
          text_blocks.map { |c| c['text'] }.join
        end

        def build_message(data, content, tool_use)
          Message.new(
            role: :assistant,
            content: content,
            tool_calls: parse_tool_calls(tool_use),
            input_tokens: data.dig('usage', 'input_tokens'),
            output_tokens: data.dig('usage', 'output_tokens'),
            model_id: data['model']
          )
        end
      end
    end
  end
end
