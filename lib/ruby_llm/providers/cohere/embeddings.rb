# frozen_string_literal: true

module RubyLLM
  module Providers
    module Cohere
      # Embeddings methods of the Cohere API integration
      # - https://docs.cohere.com/reference/embed
      # - https://docs.cohere.com/docs/embeddings
      module Embeddings
        module_function

        def embedding_url(...)
          'v2/embed'
        end

        def render_embedding_payload(input, model:, dimensions: nil)
          {
            model: model,
            embedding_types: ['float'],
            texts: Array(input),
            input_type: 'search_document',
            output_dimension: dimensions,
            truncate: 'END' # Handle long texts by truncating at the end
          }
        end

        def parse_embedding_response(response, model:)
          data = response.body
          raise Error.new(response, data['message']) if data['message'] && response.status != 200

          vectors = data.dig('embeddings', 'float') || []
          input_tokens = data.dig('meta', 'billed_units', 'input_tokens') || 0

          # If we only got one embedding, return it as a single vector
          vectors = vectors.first if vectors.length == 1

          Embedding.new(vectors:, model:, input_tokens:)
        end
      end
    end
  end
end
