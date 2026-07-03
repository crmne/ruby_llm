# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Amazon Titan text embedding models over Bedrock InvokeModel.
      class TitanTextEmbeddings < EmbeddingProtocol
        def embed(text, model:, dimensions:, params: {})
          responses = [text].flatten.map do |value|
            payload = render_embedding_payload(value, dimensions:, params:)
            signed_post(embedding_url(model:), payload)
          end

          parse_single_embedding_responses(responses, model:, text:)
        end

        private

        def render_embedding_payload(text, dimensions:, params:)
          deep_merge_params(
            {
              inputText: text.to_s,
              dimensions: dimensions,
              normalize: true
            }.compact,
            params
          )
        end
      end
    end
  end
end
