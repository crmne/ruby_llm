# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenRouter
      # Chat methods for the OpenRouter API integration
      module Chat
        module_function

        def completion_url
          'chat/completions'
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false)
          {
            model: translate_model_id(model),
            messages: format_messages(messages),
            temperature: temperature,
            stream: stream
          }.tap do |payload|
            if tools.any?
              payload[:tools] = tools.map { |_, tool| tool_for(tool) }
              payload[:tool_choice] = 'auto'
            end
          end
        end

        def parse_completion_response(response)
          data = response.body
          return if data.empty?

          message_data = data.dig('choices', 0, 'message')
          return unless message_data

          Message.new(
            role: :assistant,
            content: message_data['content'],
            tool_calls: parse_tool_calls(message_data['tool_calls']),
            input_tokens: data['usage']['prompt_tokens'],
            output_tokens: data['usage']['completion_tokens'],
            model_id: data['model']
          )
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: format_role(msg.role),
              content: msg.content
            }.compact
          end
        end

        def format_role(role)
          case role
          when :user then 'user'
          when :assistant then 'assistant'
          when :system then 'system'
          else
            raise Error, "Unknown role: #{role}"
          end
        end

        def translate_model_id(model)
          # OpenRouter uses model IDs in the format: provider/model
          # Example: anthropic/claude-3-opus-20240229
          model
        end

        private_class_method :format_role
      end
    end
  end
end 