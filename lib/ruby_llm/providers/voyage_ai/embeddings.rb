# frozen_string_literal: true

module RubyLLM
  module Providers
    class VoyageAI
      # Embeddings methods for Voyage AI API
      module Embeddings
        module_function

        def embedding_url(...)
          'embeddings'
        end

        def render_embedding_payload(text, model:, dimensions:)
          payload = {
            input: text,
            model: model
          }

          # Voyage uses 'output_dimension' parameter
          payload[:output_dimension] = dimensions if dimensions

          payload
        end

        def parse_embedding_response(response, model:, text:)
          data = response.body
          # Voyage AI uses 'total_tokens' instead of 'prompt_tokens'
          input_tokens = data.dig('usage', 'total_tokens') || 0
          vectors = data['data'].map { |d| d['embedding'] }

          # Return single vector for single text input
          vectors = vectors.first if vectors.length == 1 && !text.is_a?(Array)

          Embedding.new(vectors:, model:, input_tokens:)
        end
      end
    end
  end
end
