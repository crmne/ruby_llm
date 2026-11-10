# frozen_string_literal: true

module RubyLLM
  module Protocols
    class InvokeModel
      # Cohere embedding models over Bedrock InvokeModel.
      class CohereEmbeddings < InvokeModel
        def rejected_options(operation)
          operation == :embed ? %i[title] : super
        end

        # rubocop:disable-next Lint/UnusedMethodArgument
        def embed(text, model:, dimensions:, task_type: nil, title: nil, with: nil, provider_options: {})
          attachments = embedding_attachments(text, with)
          track_usage(:embedding) do
            payload = render_embedding_payload(text, model:, dimensions:, task_type:, attachments:, provider_options:)
            response = signed_post(embedding_url(model:), payload)

            parse_embedding_response(response, model:, text:)
          end
        end

        private

        def render_embedding_payload(text, dimensions:, provider_options:, task_type: nil, attachments: [], **)
          payload = { input_type: task_type || 'search_document' }
          payload.merge!(attachments.any? ? media_embedding_inputs(text, attachments) : text_embedding_inputs(text))
          payload[:output_dimension] = dimensions if dimensions

          deep_merge_provider_options(payload, provider_options)
        end

        def text_embedding_inputs(text)
          texts = text.is_a?(Array) ? text.map(&:to_s) : [text.to_s].reject(&:empty?)
          texts.empty? ? {} : { texts: }
        end

        def media_embedding_inputs(text, attachments)
          content = Cohere::Media.render_content(text.to_s.empty? ? nil : text, attachments)
          { inputs: [{ content: }], embedding_types: ['float'] }
        end

        def parse_embedding_response(response, model:, text:)
          vectors = response.body['embeddings']
          vectors = vectors['float'] || vectors.values.first if vectors.is_a?(Hash)
          vectors = text.is_a?(Array) ? aligned_vectors(vectors, text, response) : vectors.first

          Embedding.new(vectors:, model:,
                        input_tokens: response.headers['x-amzn-bedrock-input-token-count']&.to_i)
        end

        def aligned_vectors(vectors, text, response)
          return vectors if text.empty? || vectors.size == text.size

          raise Error.new("Expected #{text.size} embeddings, got #{vectors.size}", response:)
        end
      end
    end
  end
end
