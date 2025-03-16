# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenRouter
      # Defines the capabilities of the OpenRouter API integration
      module Capabilities
        module_function

        def chat?
          true
        end

        def embeddings?
          true
        end

        def images?
          false # Will be implemented in phase 2
        end

        def streaming?
          true
        end

        def tools?
          true
        end

        def function_calling?
          true
        end
      end
    end
  end
end 