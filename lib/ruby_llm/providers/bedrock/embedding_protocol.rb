# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Shared transport helpers for Bedrock embedding dialects.
      class EmbeddingProtocol < Protocol
        include Bedrock::SignedRequests

        private

        def embedding_url(model:)
          "/model/#{model}/invoke"
        end

        def parse_single_embedding_responses(responses, model:, text:)
          vectors = responses.map { |response| extract_embedding(response.body) }
          input_tokens = responses.sum { |response| response.body['inputTextTokenCount'] || 0 }
          vectors = vectors.first unless text.is_a?(Array)

          Embedding.new(vectors:, model:, input_tokens:)
        end

        def deep_merge_provider_options(payload, provider_options)
          return payload if provider_options.empty?

          Utils.deep_merge(payload, provider_options)
        end

        def extract_embedding(body)
          body['embedding'] || body.dig('embeddingsByType', 'float') || body['embeddingsByType']&.values&.first
        end
      end
    end
  end
end
