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
      end
    end
  end
end
