# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Amazon Titan multimodal embedding models over Bedrock InvokeModel.
      class TitanMultimodalEmbeddings < EmbeddingProtocol
        def embed(text, model:, dimensions:, params: {})
          responses = [text].flatten.map do |value|
            payload = render_embedding_payload(value, dimensions:, params:)
            signed_post(embedding_url(model:), payload)
          end

          parse_single_embedding_responses(responses, model:, text:)
        end

        private

        def render_embedding_payload(text, dimensions:, params:)
          payload = {}
          payload[:inputText] = text.to_s unless text.nil? || text.to_s.empty?
          payload[:embeddingConfig] = { outputEmbeddingLength: dimensions } if dimensions

          deep_merge_params(payload, params)
        end
      end
    end
  end
end
