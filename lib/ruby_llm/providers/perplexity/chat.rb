# frozen_string_literal: true

module RubyLLM
  module Providers
    module Perplexity
      # Chat methods of the Perplexity API integration
      module Chat
        module_function

        def completion_url
          'chat/completions'
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false)
          {
            model: model,
            messages: format_messages(messages),
            temperature: temperature,
            stream: stream
          }
        end

        def parse_completion_response(response)
          data = response.body
          return if data.empty?

          message_data = data.dig('choices', 0, 'message')
          return unless message_data

          # Create a message with citations if available
          content = message_data['content']
          
          Message.new(
            role: :assistant,
            content: content,
            input_tokens: data['usage']['prompt_tokens'],
            output_tokens: data['usage']['completion_tokens'],
            model_id: data['model'],
            metadata: {
              citations: data['citations']
            }
          )
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: msg.role.to_s,
              content: msg.content
            }
          end
        end
      end
    end
  end
end
