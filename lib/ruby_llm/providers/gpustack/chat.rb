# frozen_string_literal: true

module RubyLLM
  module Providers
    class GPUStack
      # Chat methods of the GPUStack API integration
      module Chat
        module_function

        def format_messages(messages)
          messages.map do |msg|
            {
              role: format_role(msg.role),
              content: format_message_content(msg),
              tool_calls: format_tool_calls(msg.tool_calls),
              tool_call_id: msg.tool_call_id
            }.compact.merge(OpenAI::Chat.format_thinking(msg))
          end
        end

        def format_message_content(msg)
          content = GPUStack::Media.format_content(msg.content)
          return '' if content.nil? && OpenAI::Chat.thinking_only_assistant_message?(msg)

          content
        end

        def format_role(role)
          role.to_s
        end
      end
    end
  end
end
