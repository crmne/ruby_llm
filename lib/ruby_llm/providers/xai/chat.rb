# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # Chat implementation for xAI
      # https://docs.x.ai/docs/api-reference#chat-completions
      module Chat
        def format_role(role)
          role.to_s
        end
      end
    end
  end
end
