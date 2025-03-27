# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Embeddings methods of the OpenAI API integration
      module Embeddings
        module_function

        def embedding_url
          'embeddings'
        end

        def render_embedding_payload(text, model:, dimensions:)
          {
            model: model,
            input: text,
            dimensions: dimensions
          }.compact
        end

        def parse_embedding_response(response)
          data = response.body
          model_id = data['model']
          input_tokens = data.dig('usage', 'prompt_tokens') || 0
          vectors = data['data'].map { |d| d['embedding'] }

          # If we only got one embedding, return it as a single vector
          vectors = vectors.first if vectors.size == 1

          Embedding.new(
            vectors: vectors,
            model: model_id,
            input_tokens: input_tokens
          )
        end
      end
    end
  end
end
