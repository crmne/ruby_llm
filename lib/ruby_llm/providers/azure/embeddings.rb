# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Embeddings methods of the Azure AI Foundry API integration
      module Embeddings
        module_function

        def embedding_url(...)
          'openai/v1/embeddings'
        end

        def render_embedding_payload(text, model:, dimensions:)
          {
            model: model,
            input: [text].flatten,
            dimensions: dimensions
          }.compact
        end
      end
    end
  end
end
