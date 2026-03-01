# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Chat methods of the Azure AI Foundry API integration
      module Chat
        def completion_url
          azure_endpoint(:chat)
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: format_role(msg.role),
              content: Media.format_content(msg.content),
              tool_calls: format_tool_calls(msg.tool_calls),
              tool_call_id: msg.tool_call_id
            }.compact.merge(format_thinking(msg))
          end
        end

        def format_role(role)
          role.to_s
        end
      end
    end
  end
end
