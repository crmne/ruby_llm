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

        def render_embedding_payload(text, model:, dimensions:, params: {}) # rubocop:disable Lint/UnusedMethodArgument
          params = params.dup
          task_type = params.delete(:task_type) || params.delete('task_type')
          title = params.delete(:title) || params.delete('title')

          payload = {
            instances: [text].flatten.map do |t|
              { content: t.to_s }.tap do |instance|
                instance[:task_type] = task_type if task_type
                instance[:title] = title if title
              end
            end
          }.tap do |payload|
            payload[:parameters] = { outputDimensionality: dimensions } if dimensions
          end

          Utils.deep_merge(payload, params)
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
