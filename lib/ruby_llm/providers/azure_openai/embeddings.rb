# frozen_string_literal: true

module RubyLLM
  module Providers
    class AzureOpenAI
      # Embeddings methods for the Azure OpenAI API integration
      module Embeddings
        def embedding_url(model:)
          "deployments/#{model}/embeddings?api-version=#{@config.azure_openai_api_version}"
        end
      end
    end
  end
end
