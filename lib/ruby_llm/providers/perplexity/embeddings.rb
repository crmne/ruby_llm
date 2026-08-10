# frozen_string_literal: true

module RubyLLM
  module Providers
    class Perplexity
      # Embeddings methods of the Perplexity API integration
      module Embeddings
        module_function

        def embedding_url(...)
          'v1/embeddings'
        end

        # Perplexity serves base64-encoded signed int8 vectors.
        def parse_embedding_response(response, model:, text:)
          data = response.body
          input_tokens = data.dig('usage', 'prompt_tokens')
          vectors = Array(data['data']).map { |vector| decode_embedding(vector['embedding']) }
          vectors = vectors.first if vectors.length == 1 && !text.is_a?(Array)

          Embedding.new(vectors:, model:, input_tokens:)
        end

        def decode_embedding(embedding)
          return embedding unless embedding.is_a?(String)

          Base64.decode64(embedding).unpack('c*')
        end
      end
    end
  end
end
