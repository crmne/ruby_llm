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

        def render_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil, **) # rubocop:disable Lint/UnusedMethodArgument
          instances = [text].flatten.map do |t|
            instance = { content: t.to_s }
            instance[:task_type] = task_type if task_type
            instance[:title] = title if title
            instance
          end

          { instances: instances }.tap do |payload|
            payload[:parameters] = { outputDimensionality: dimensions } if dimensions
          end
        end

        def parse_embedding_response(response, model:, text:)
          predictions = response.body['predictions']
          vectors = predictions&.map { |p| p.dig('embeddings', 'values') }
          vectors = vectors.first if vectors&.length == 1 && !text.is_a?(Array)

          Embedding.new(vectors:, model:, input_tokens: 0)
        end
      end
    end
  end
end
