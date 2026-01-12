# frozen_string_literal: true

module RubyLLM
  module Providers
    class AzureOpenAI
      # Models methods of the Azure OpenAI API integration
      module Models
        KNOWN_MODELS = [
          # Chat models
          'gpt-4o',
          'gpt-4o-mini',
          'gpt-4.1',
          'gpt-4.1-mini',
          'gpt-4.1-nano',
          'gpt-4',
          # Reasoning models (o-series)
          'o1',
          'o1-mini',
          'o3',
          'o3-mini',
          'o3-pro',
          'o4-mini',
          # Embedding models
          'text-embedding-3-large',
          'text-embedding-3-small',
          # Image generation
          'dall-e-3',
          'gpt-image-1',
          'gpt-image-1-mini'
        ].freeze

        def models_url
          'models?api-version=2024-10-21'
        end

        def parse_list_models_response(response, slug, capabilities)
          # select the known models only since this list from Azure OpenAI is
          # very long
          response.body['data'].select! do |m|
            KNOWN_MODELS.include?(m['id'])
          end
          # Use the OpenAI processor for the list, keeping in mind that pricing etc
          # won't be correct
          super
        end
      end
    end
  end
end
