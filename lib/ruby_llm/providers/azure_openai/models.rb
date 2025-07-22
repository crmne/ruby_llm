# frozen_string_literal: true

module RubyLLM
  module Providers
    module AzureOpenAI
      # Models methods of the OpenAI API integration
      module Models
        extend OpenAI::Models

        KNOWN_MODELS = [
          'gpt-4o'
        ].freeze

        module_function

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
