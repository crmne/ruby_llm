# frozen_string_literal: true

module RubyLLM
  module Providers
    module Cohere
      # Chat methods of the Cohere API integration
      # - https://docs.cohere.com/reference/chat
      # - https://docs.cohere.com/docs/chat-api
      module Chat
        def completion_url
          'v2/chat'
        end

        module_function

        def render_payload(messages, tools:, temperature:, model:, stream: false)
          @model_id = model

          {
            model: model,
            messages: format_messages(messages),
            temperature: temperature,
            stream: stream,
            tools: tools.any? ? tools.map { |_, tool| Tools.tool_for(tool) } : nil
          }.compact
        end

        def parse_completion_response(response)
          data = response.body
          return if data.empty?

          raise Error.new(response, data['message']) if data['message'] && response.status != 200

          message_data = data['message']
          return unless message_data

          Message.new(
            role: message_data['role'].to_sym,
            content: message_data.dig('content', 0, 'text'),
            tool_calls: Tools.parse_tool_calls(message_data['tool_calls']),
            input_tokens: data.dig('usage', 'tokens', 'input_tokens'),
            output_tokens: data.dig('usage', 'tokens', 'output_tokens'),
            model_id: @model_id
          )
        end

        def format_messages(messages)
          messages.map { |msg| format_message(msg) }
        end

        def format_message(msg)
          if msg.tool_call?
            Tools.format_tool_call(msg)
          elsif msg.tool_result?
            Tools.format_tool_result(msg)
          else
            format_basic_message(msg)
          end
        end

        def format_basic_message(msg)
          {
            role: format_role(msg.role),
            content: Media.format_content(msg.content)
          }.compact
        end

        def format_role(role)
          case role
          when :system
            'system'
          when :user, :tool
            'user'
          when :assistant
            'assistant'
          else
            role.to_s
          end
        end
      end
    end
  end
end
