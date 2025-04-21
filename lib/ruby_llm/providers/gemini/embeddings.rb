# frozen_string_literal: true

module RubyLLM
  module Providers
    module Gemini
      # Embeddings methods for the Gemini API integration
      module Embeddings
        # Must be public for Provider module
        def embed(text, model:, connection:) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          payload = {
            content: {
              parts: format_text_for_embedding(text)
            }
          }

          url = "models/#{model}:embedContent"
          response = connection.post url, payload

          if text.is_a?(Array)
            # We need to make separate calls for each text with Gemini
            embeddings = text.map do |t|
              single_payload = { content: { parts: [{ text: t.to_s }] } }
              single_response = connection.post url, single_payload
              single_response.body.dig('embedding', 'values')
            end

            Embedding.new(
              vectors: embeddings,
              model: model,
              input_tokens: response.body.dig('usageMetadata', 'promptTokenCount') || 0
            )
          else
            Embedding.new(
              vectors: response.body.dig('embedding', 'values'),
              model: model,
              input_tokens: response.body.dig('usageMetadata', 'promptTokenCount') || 0
            )
          end
        end

        private

        def format_text_for_embedding(text)
          if text.is_a?(Array)
            text.map { |t| { text: t.to_s } }
          else
            [{ text: text.to_s }]
          end
        end
      end
    end
  end
end
