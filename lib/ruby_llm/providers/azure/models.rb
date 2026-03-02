# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Models methods of the Azure AI Foundry API integration
      module Models
        def models_url
          azure_endpoint(:models)
        end
      end
    end
  end
end
