# frozen_string_literal: true

module RubyLLM
  module Providers
    module DeepSeek
      # Chat methods of the DeepSeek API integration
      module Chat
        module_function

        def format_role(role)
          # DeepSeek doesn't use the new OpenAI convention for system prompts
          role.to_s
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, chat: nil)
          {
            model: model,
            messages: format_messages(messages),
            temperature: temperature,
            stream: stream
          }.tap do |payload|
            if tools.any?
              payload[:tools] = tools.map { |_, tool| format_tool(tool) }
            end
          end
        end
      end
    end
  end
end
