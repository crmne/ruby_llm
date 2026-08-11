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

        def render_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil, with: [],
                                     provider_options: {})
          requests = if with.any?
                       raise ArgumentError, 'embed one text at a time when embedding attachments' if text.is_a?(Array)

                       [media_embedding_payload(text, with, model:, dimensions:, task_type:, title:)]
                     else
                       [text].flatten.map do |t|
                         single_embedding_payload(t, model:, dimensions:, task_type:, title:)
                       end
                     end

          Utils.deep_merge({ requests: requests }, provider_options)
        end

        def supports_embedding_media?
          true
        end

        def parse_embedding_response(response, model:, text:)
          vectors = response.body['embeddings']&.map { |e| e['values'] }
          vectors = vectors.first if vectors&.length == 1 && !text.is_a?(Array)

          Embedding.new(vectors:, model:)
        end

        private

        def single_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil)
          embedding_payload([{ text: text.to_s }], model:, dimensions:, task_type:, title:)
        end

        def media_embedding_payload(text, attachments, model:, dimensions:, task_type: nil, title: nil)
          embedding_payload(Media.format_content(text, attachments), model:, dimensions:, task_type:, title:)
        end

        def embedding_payload(parts, model:, dimensions:, task_type:, title:)
          {
            model: "models/#{model}",
            content: { parts: parts },
            outputDimensionality: dimensions,
            taskType: task_type,
            title: title
          }.compact
        end
      end
    end
  end
end
