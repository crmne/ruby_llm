# frozen_string_literal: true

module RubyLLM
  module Providers
    module AzureOpenAI
      # Models methods of the OpenAI API integration
      module Models
        extend OpenAI::Models

        module_function

        def models_url
          'models?api-version=2024-10-21'
        end
      end
    end
  end
end
