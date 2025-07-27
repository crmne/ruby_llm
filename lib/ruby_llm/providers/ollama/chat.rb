# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Chat methods of the Ollama API integration
      module Chat
        module_function

        def completion_url
          'chat'
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: format_role(msg.role),
              content: Ollama::Media.format_content(msg.content),
              tool_calls: format_tool_calls(msg.tool_calls),
              tool_call_id: msg.tool_call_id
            }.compact
          end
        end

        def parse_completion_response(response)
          data = response.body
          return if data.empty?

          raise Error.new(response, data.dig('error', 'message')) if data.dig('error', 'message')

          message_data = data['message']
          return unless message_data

          Message.new(
            role: :assistant,
            content: message_data['content'],
            tool_calls: parse_tool_calls(message_data['tool_calls']),
            input_tokens: data['prompt_eval_count'],
            output_tokens: data['eval_count'],
            model_id: data['model']
          )
        end

        def format_role(role)
          # Ollama doesn't use the new OpenAI convention for system prompts
          role.to_s
        end
      end
    end
  end
end
