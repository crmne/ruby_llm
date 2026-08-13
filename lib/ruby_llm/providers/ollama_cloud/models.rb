# frozen_string_literal: true

module RubyLLM
  module Providers
    class OllamaCloud
      # Models methods for the Ollama Cloud API integration
      module Models
        def model_capabilities
          super - %w[structured_output]
        end
      end
    end
  end
end
