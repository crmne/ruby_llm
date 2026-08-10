# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Amazon Titan multimodal embedding models over Bedrock InvokeModel.
      class TitanMultimodalEmbeddings < EmbeddingProtocol
        # rubocop:disable Lint/UnusedMethodArgument
        def embed(text, model:, dimensions:, task_type: nil, title: nil, provider_options: {})
          track_usage(:embedding) do
            responses = [text].flatten.map do |value|
              payload = render_embedding_payload(value, dimensions:, provider_options:)
              signed_post(embedding_url(model:), payload).tap { |response| record_embedding_attempt(response) }
            end

            parse_single_embedding_responses(responses, model:, text:)
          end
        end
        # rubocop:enable Lint/UnusedMethodArgument

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
