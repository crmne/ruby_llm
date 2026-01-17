# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Chat methods for the AWS Bedrock API implementation
      module Chat
        module_function

        def sync_response(connection, payload, additional_headers = {})
          signature = sign_request("#{connection.connection.url_prefix}#{completion_url}", payload:)
          response = connection.post completion_url, payload do |req|
            req.headers.merge! build_headers(signature.headers, streaming: block_given?)
            req.headers = additional_headers.merge(req.headers) unless additional_headers.empty?
          end
          Anthropic::Chat.parse_completion_response response
        end

        def format_message(msg, thinking: nil)
          thinking_enabled = thinking&.enabled?

          if msg.tool_call?
            format_tool_call_with_thinking(msg, thinking_enabled)
          elsif msg.tool_result?
            Anthropic::Tools.format_tool_result(msg)
          else
            format_basic_message_with_thinking(msg, thinking_enabled)
          end
        end

        private

        def completion_url
          "model/#{@model_id}/invoke"
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil, thinking: nil) # rubocop:disable Lint/UnusedMethodArgument,Metrics/ParameterLists
          @model_id = model.id

          system_messages, chat_messages = Anthropic::Chat.separate_messages(messages)
          system_content = Anthropic::Chat.build_system_content(system_messages)

          build_base_payload(chat_messages, model, thinking).tap do |payload|
            Anthropic::Chat.add_optional_fields(payload, system_content:, tools:, temperature:)
          end
        end

        def build_base_payload(chat_messages, model, thinking)
          payload = {
            anthropic_version: 'bedrock-2023-05-31',
            messages: chat_messages.map { |msg| format_message(msg, thinking: thinking) },
            max_tokens: model.max_tokens || 4096
          }

          thinking_payload = Anthropic::Chat.build_thinking_payload(thinking)
          payload[:thinking] = thinking_payload if thinking_payload

          payload
        end

        def format_basic_message_with_thinking(msg, thinking_enabled)
          content_blocks = []

          if msg.role == :assistant && thinking_enabled
            thinking_block = Anthropic::Chat.build_thinking_block(msg.thinking)
            content_blocks << thinking_block if thinking_block
          end

          append_formatted_content(content_blocks, msg.content)

          {
            role: Anthropic::Chat.convert_role(msg.role),
            content: content_blocks
          }
        end

        def format_tool_call_with_thinking(msg, thinking_enabled)
          if msg.content.is_a?(RubyLLM::Content::Raw)
            content_blocks = msg.content.value
            content_blocks = [content_blocks] unless content_blocks.is_a?(Array)
            content_blocks = Anthropic::Chat.prepend_thinking_block(content_blocks, msg, thinking_enabled)

            return { role: 'assistant', content: content_blocks }
          end

          content_blocks = Anthropic::Chat.prepend_thinking_block([], msg, thinking_enabled)
          content_blocks << Anthropic::Media.format_text(msg.content) unless msg.content.nil? || msg.content.empty?

          msg.tool_calls.each_value do |tool_call|
            content_blocks << {
              type: 'tool_use',
              id: tool_call.id,
              name: tool_call.name,
              input: tool_call.arguments
            }
          end

          {
            role: 'assistant',
            content: content_blocks
          }
        end

        def append_formatted_content(content_blocks, content)
          formatted_content = Media.format_content(content)
          if formatted_content.is_a?(Array)
            content_blocks.concat(formatted_content)
          else
            content_blocks << formatted_content
          end
        end
      end
    end
  end
end
