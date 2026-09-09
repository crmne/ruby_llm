# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI
      # Gemini Embedding 2 over Vertex AI's single-content embedding endpoint.
      class EmbedContent < Protocols::Gemini
        def embedding_url(model:)
          "#{@provider.model_path(model)}:embedContent"
        end

        def render_embedding(text, **options)
          return super unless text.is_a?(Array)

          { requests: text.map { |value| render_embedding_payload(value, **options) } }
        end

        def render_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil, with: [],
                                     provider_options: {})
          if text.is_a?(Array) && text.size != 1
            raise ArgumentError, 'Vertex AI embedContent accepts one text at a time'
          end
          raise ArgumentError, "#{model} takes task instructions and titles in the text" if task_type || title

          payload = {
            content: { parts: Protocols::Gemini::Media.format_content(text.is_a?(Array) ? text.first : text, with) },
            outputDimensionality: dimensions
          }.compact
          Support::Utils.deep_merge(payload, provider_options)
        end

        def parse_embedding_response(response, model:, text:)
          vectors = response.body.dig('embedding', 'values')
          raise Error.new('Vertex AI returned no embedding', response:) if vectors.nil? || vectors.empty?

          vectors = [vectors] if text.is_a?(Array)
          Embedding.new(vectors:, model:, input_tokens: response.body.dig('usageMetadata', 'promptTokenCount'))
        end
      end
    end
  end
end
