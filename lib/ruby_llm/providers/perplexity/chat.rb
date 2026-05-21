# frozen_string_literal: true

module RubyLLM
  module Providers
    class Perplexity
      # Chat formatting for Perplexity provider
      module Chat
        module_function

        def format_role(role)
          role.to_s
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: format_role(msg.role),
              content: Perplexity::Media.format_content(msg.content),
              tool_calls: OpenAI::Tools.format_tool_calls(msg.tool_calls),
              tool_call_id: msg.tool_call_id
            }.compact.merge(OpenAI::Chat.format_thinking(msg))
          end
        end
      end
    end
  end
end
