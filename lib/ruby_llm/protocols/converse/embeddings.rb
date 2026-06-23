# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Converse
      # Embeddings methods for Bedrock's InvokeModel API.
      module Embeddings
        def embed(text, model:, dimensions:)
          responses = [text].flatten.map do |value|
            payload = render_embedding_payload(value, model:, dimensions:)
            signed_post(embedding_url(model:), payload)
          end

          parse_embedding_responses(responses, model:, text:)
        end

        private

        def embedding_url(model:)
          "/model/#{model}/invoke"
        end

        def render_embedding_payload(text, model:, dimensions:) # rubocop:disable Lint/UnusedMethodArgument
          {
            inputText: text.to_s,
            dimensions: dimensions,
            normalize: true
          }.compact
        end

        def parse_embedding_responses(responses, model:, text:)
          vectors = responses.map { |response| response.body['embedding'] }
          input_tokens = responses.sum { |response| response.body['inputTextTokenCount'] || 0 }
          vectors = vectors.first unless text.is_a?(Array)

          Embedding.new(vectors:, model:, input_tokens:)
        end
      end
    end
  end
end
