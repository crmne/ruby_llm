# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Embeddings methods for the Gemini API integration
      module Embeddings
        module_function

        def embedding_url(model:)
          "models/#{model}:batchEmbedContents"
        end

        def render_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil, provider_options: {}) # rubocop:disable Metrics/ParameterLists
          requests = [text].flatten.map do |t|
            single_embedding_payload(t, model:, dimensions:, task_type:, title:)
          end

          Utils.deep_merge({ requests: requests }, provider_options)
        end

        def parse_embedding_response(response, model:, text:)
          vectors = response.body['embeddings']&.map { |e| e['values'] }
          vectors = vectors.first if vectors&.length == 1 && !text.is_a?(Array)

          Embedding.new(vectors:, model:, input_tokens: 0)
        end

        private

        def single_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil)
          {
            model: "models/#{model}",
            content: { parts: [{ text: text.to_s }] },
            outputDimensionality: dimensions,
            taskType: task_type,
            title: title
          }.compact
        end
      end
    end
  end
end
