# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Embeddings methods for Mistral API
      module Embeddings
        module_function

        def embedding_url(...)
          'embeddings'
        end

        # rubocop:disable-next Lint/UnusedMethodArgument
        def render_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil, provider_options: {})
          {
            model: model,
            input: text,
            output_dimension: dimensions
          }.compact.merge(provider_options)
        end
      end
    end
  end
end
