# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI
      # Embeddings methods for the Vertex AI implementation
      module Embeddings
        module_function

        def embedding_url(model:)
          "#{@provider.model_path(model)}:predict"
        end

        def supports_embedding_media?
          false
        end

        # rubocop:disable Lint/UnusedMethodArgument
        def render_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil, provider_options: {})
          instances = [text].flatten.map do |t|
            { content: t.to_s, task_type: task_type, title: title }.compact
          end
          payload = { instances: instances }
          payload[:parameters] = { outputDimensionality: dimensions } if dimensions

          Utils.deep_merge(payload, provider_options)
        end
        # rubocop:enable Lint/UnusedMethodArgument

        def parse_embedding_response(response, model:, text:)
          predictions = response.body['predictions']
          vectors = predictions&.map { |p| p.dig('embeddings', 'values') }
          input_tokens = embedding_input_tokens(predictions)
          vectors = vectors.first if vectors&.length == 1 && !text.is_a?(Array)

          Embedding.new(vectors:, model:, input_tokens:)
        end

        def embedding_input_tokens(predictions)
          counts = Array(predictions).filter_map do |prediction|
            prediction.dig('embeddings', 'statistics', 'token_count')
          end
          counts.sum unless counts.empty?
        end
      end
    end
  end
end
