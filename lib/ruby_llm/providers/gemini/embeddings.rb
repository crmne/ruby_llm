# frozen_string_literal: true

module RubyLLM
  module Providers
    module Gemini
      # Embeddings methods for the Gemini API integration
      module Embeddings
        # Must be public for Provider module
        def embed(text, model:, dimensions: nil) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          if text.is_a?(Array)
            # We need to make separate calls for each text with Gemini
            embeddings = []
            input_tokens = text.reduce(0) do |acc, t|
              response = request_single_embedding(t, model:, dimensions:)
              embeddings << response.body.dig('embedding', 'values')

              acc + (response.body.dig('usageMetadata', 'promptTokenCount') || 0)
            end

            Embedding.new(
              vectors: embeddings,
              model: model,
              input_tokens: input_tokens
            )
          else
            response = request_single_embedding(text, model:, dimensions:)

            Embedding.new(
              vectors: response.body.dig('embedding', 'values'),
              model: model,
              input_tokens: response.body.dig('usageMetadata', 'promptTokenCount') || 0
            )
          end
        end

        private

        def request_single_embedding(text, model:, dimensions:)
          url = "models/#{model}:embedContent"
          payload = {
            content: {
              parts: [{ text: text.to_s }]
            },
            outputDimensionality: dimensions
          }.compact

          post(url, payload)
        end
      end
    end
  end
end
