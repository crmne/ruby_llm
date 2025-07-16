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
              role: format_role(msg.role),
              content: Media.format_content(msg.content),
              tool_calls: format_tool_calls(msg.tool_calls),
              tool_call_id: msg.tool_call_id
            }.compact
          end
        end
      end
    end
  end
end
