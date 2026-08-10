# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Amazon Nova multimodal embedding models over Bedrock InvokeModel.
      class NovaEmbeddings < EmbeddingProtocol
        DEFAULT_EMBEDDING_PURPOSE = 'GENERIC_INDEX'

        # rubocop:disable Lint/UnusedMethodArgument
        def embed(text, model:, dimensions:, task_type: nil, title: nil, provider_options: {})
          track_usage(:embedding) do
            responses = [text].flatten.map do |value|
              payload = render_embedding_payload(value, dimensions:, task_type:, provider_options:)
              signed_post(embedding_url(model:), payload).tap { |response| record_embedding_attempt(response) }
            end

            parse_single_embedding_responses(responses, model:, text:)
          end
        end
        # rubocop:enable Lint/UnusedMethodArgument

        private

        def render_embedding_payload(text, dimensions:, task_type:, provider_options:)
          params = {
            embeddingPurpose: task_type || DEFAULT_EMBEDDING_PURPOSE,
            text: {
              truncationMode: 'END',
              value: text.to_s
            }
          }
          params[:embeddingDimension] = dimensions if dimensions

          deep_merge_provider_options(
            {
              taskType: 'SINGLE_EMBEDDING',
              singleEmbeddingParams: params
            },
            provider_options
          )
        end

        def extract_embedding(body)
          body.dig('embeddings', 0, 'embedding')
        end
      end
    end
  end
end
