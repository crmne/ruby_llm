# frozen_string_literal: true

module RubyLLM
  module Providers
    module Dify
      # Chat methods of the Dify API integration
      module Chat
        def completion_url
          'v1/chat-messages'
        end

        module_function

        def render_payload(messages, tools:, temperature:, model:, stream: false) # rubocop:disable Lint/UnusedMethodArgument
          payload = {
            inputs: {},
            query: messages[0].content,
            response_mode: (stream ? 'streaming' : 'blocking'),
            conversation_id: '',
            user: 'dify-user'
          }
          payload
        end

        private

        def parse_completion_response(response)
          data = response.body

          Message.new(
            role: :assistant,
            content: data['answer'],
            tool_calls: nil,
            input_tokens: data.dig('metadata', 'usage', 'prompt_tokens'),
            output_tokens: data.dig('metadata', 'usage', 'completion_tokens'),
            model_id: 'dify-model'
          )
        end
      end
    end
  end
end
