# frozen_string_literal: true

module RubyLLM
  module Protocols
    class InvokeModel
      # Cohere embedding models over Bedrock InvokeModel.
      class CohereEmbeddings < InvokeModel
        # rubocop:disable Lint/UnusedMethodArgument
        def embed(text, model:, dimensions:, task_type: nil, title: nil, with: nil, provider_options: {})
          ensure_no_embedding_media!(with)
          track_usage(:embedding) do
            payload = render_embedding_payload(text, model:, dimensions:, task_type:, provider_options:)
            response = signed_post(embedding_url(model:), payload)

            parse_embedding_response(response, model:, text:)
          end
        end
        # rubocop:enable Lint/UnusedMethodArgument

        private

        def render_embedding_payload(text, model:, dimensions:, provider_options:, task_type: nil)
          payload = {
            input_type: task_type || 'search_document'
          }
          texts = [text].flatten.compact.map(&:to_s).reject(&:empty?)
          payload[:texts] = texts unless texts.empty?

          if dimensions
            raise Error, "#{model} does not support custom dimensions" unless cohere_v4?(model)

            payload[:output_dimension] = dimensions
          end

          deep_merge_provider_options(payload, provider_options)
        end

        def parse_embedding_response(response, model:, text:)
          vectors = response.body['embeddings']
          vectors = vectors['float'] || vectors.values.first if vectors.is_a?(Hash)
          vectors = vectors.first unless text.is_a?(Array)

          Embedding.new(vectors:, model:)
        end

        def cohere_v4?(model)
          model.to_s.include?('cohere.embed-v4')
        end
      end
    end
  end
end
