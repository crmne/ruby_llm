# frozen_string_literal: true

module RubyLLM
  module Providers
    module Perplexity
      # Chat formatting for Perplexity provider
      module Chat
        module_function

        def format_role(role)
          # Perplexity doesn't use the new OpenAI convention for system prompts
          role.to_s
        end
      end
    end
  end
end
