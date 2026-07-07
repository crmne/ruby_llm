# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Amazon Titan multimodal embedding models over Bedrock InvokeModel.
      class TitanMultimodalEmbeddings < EmbeddingProtocol
        # rubocop:disable Lint/UnusedMethodArgument, Metrics/ParameterLists
        def embed(text, model:, dimensions:, task_type: nil, title: nil, provider_options: {})
          responses = [text].flatten.map do |value|
            payload = render_embedding_payload(value, dimensions:, provider_options:)
            signed_post(embedding_url(model:), payload)
          end

          parse_single_embedding_responses(responses, model:, text:)
        end
        # rubocop:enable Lint/UnusedMethodArgument, Metrics/ParameterLists

        private

        def render_embedding_payload(text, dimensions:, provider_options:)
          payload = {}
          payload[:inputText] = text.to_s unless text.nil? || text.to_s.empty?
          payload[:embeddingConfig] = { outputEmbeddingLength: dimensions } if dimensions

          deep_merge_provider_options(payload, provider_options)
        end
      end
    end
  end
end
