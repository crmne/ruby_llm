# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Chat methods for the AWS Bedrock API implementation
      module Chat
        module_function

        def sync_response(connection, payload)
          signature = sign_request("#{connection.connection.url_prefix}#{completion_url}", config: connection.config,
                                                                                           payload:)
          response = connection.post completion_url, payload do |req|
            req.headers.merge! build_headers(signature.headers, streaming: block_given?)
          end
          Anthropic::Chat.parse_completion_response response
        end

        def format_message(msg)
          if msg.tool_call?
            Anthropic::Tools.format_tool_call(msg)
          elsif msg.tool_result?
            Anthropic::Tools.format_tool_result(msg)
          else
            format_basic_message(msg)
          end
        end

        def format_basic_message(msg)
          {
            role: Anthropic::Chat.convert_role(msg.role),
            content: Media.format_content(msg.content)
          }
        end

        private

        def completion_url
          "model/#{@model_id}/invoke"
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false) # rubocop:disable Lint/UnusedMethodArgument
          # Hold model_id in instance variable for use in completion_url and stream_url
          @model_id = model

          system_messages, chat_messages = Anthropic::Chat.separate_messages(messages)
          system_content = Anthropic::Chat.build_system_content(system_messages)

          build_base_payload(chat_messages, temperature, model).tap do |payload|
            Anthropic::Chat.add_optional_fields(payload, system_content:, tools:)
          end
        end

        def build_base_payload(chat_messages, temperature, model)
          {
            anthropic_version: 'bedrock-2023-05-31',
            messages: chat_messages.map { |msg| format_message(msg) },
            temperature: temperature,
            max_tokens: RubyLLM.models.find(model)&.max_tokens || 4096
          }
        end
      end
    end
  end
end
