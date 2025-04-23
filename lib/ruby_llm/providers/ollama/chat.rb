# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Chat methods of the Ollama API integration
      module Chat
        module_function

        def format_role(role)
          # Ollama doesn't use the new OpenAI convention for system prompts
          role.to_s
        end
      end
    end
  end
end
