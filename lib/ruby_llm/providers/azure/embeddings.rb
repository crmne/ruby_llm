# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Embeddings methods of the Azure AI Foundry API integration
      module Embeddings
        module_function

        def embedding_url(...)
          azure_endpoint(:embeddings)
        end

        # rubocop:disable Lint/UnusedMethodArgument, Metrics/ParameterLists
        def render_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil, provider_options: {})
          {
            model: model,
            input: [text].flatten,
            dimensions: dimensions
          }.compact.merge(provider_options)
        end
        # rubocop:enable Lint/UnusedMethodArgument, Metrics/ParameterLists
      end
    end
  end
end
