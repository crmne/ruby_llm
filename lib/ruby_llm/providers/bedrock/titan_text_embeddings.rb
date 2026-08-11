# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Amazon Titan text embedding models over Bedrock InvokeModel.
      class TitanTextEmbeddings < EmbeddingProtocol
        # rubocop:disable Lint/UnusedMethodArgument
        def embed(text, model:, dimensions:, task_type: nil, title: nil, with: nil, provider_options: {})
          ensure_no_embedding_media!(with)
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
          deep_merge_provider_options(
            {
              inputText: text.to_s,
              dimensions: dimensions,
              normalize: true
            }.compact,
            provider_options
          )
        end
      end
    end
  end
end
