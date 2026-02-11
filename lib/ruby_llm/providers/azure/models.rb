# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Models methods of the Azure AI Foundry API integration
      module Models
        def models_url
          'openai/v1/models?api-version=preview'
        end
      end
    end
  end
end
