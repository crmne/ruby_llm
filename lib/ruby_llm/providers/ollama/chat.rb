# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Chat methods for the Ollama API implementation
      module Chat
        module_function

        def completion_url
          'api/chat'
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false)
          raise NotImplementedError, 'tool use not implemented in Ollama at this time' if tools.any?

          {
            model: model,
            messages: format_messages(messages),
            options: {
              temperature: temperature
            },
            stream: stream
          }
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: msg.role.to_s,
              content: msg.content.to_s
            }
          end
        end

        def parse_completion_response(response)
          data = response.body

          Message.new(
            role: :assistant,
            content: data.dig('message', 'content'),
            input_tokens: data['prompt_eval_count'].to_i,
            output_tokens: data['eval_count'].to_i,
            model_id: data['model']
          )
        end
      end
    end
  end
end
