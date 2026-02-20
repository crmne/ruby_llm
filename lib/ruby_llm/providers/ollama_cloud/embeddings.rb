# frozen_string_literal: true

module RubyLLM
  module Providers
    class OllamaCloud
      # Embeddings methods for the Ollama Cloud API
      module Embeddings
        def embedding_url(model:)
          'api/embed'
        end

        def render_embedding_payload(text, model:, dimensions: nil)
          {
            model: model.id,
            input: text
          }

          # Ollama doesn't directly support dimensions parameter
          # but some models have specific embedding sizes
        end

        def parse_embedding_response(response, model:, text:)
          data = response.body

          raise Error, data.dig('error', 'message') || 'Embedding failed' if data['error']

          embeddings = data['embeddings']

          if text.is_a?(Array)
            # Batch embedding
            embeddings.map.with_index do |embedding, i|
              Embedding.new(
                text: text[i],
                embedding: embedding,
                model_id: model.id,
                input_tokens: data.dig('usage', 'prompt_tokens')
              )
            end
          else
            # Single embedding
            Embedding.new(
              text: text,
              embedding: embeddings.first,
              model_id: model.id,
              input_tokens: data.dig('usage', 'prompt_tokens')
            )
          end
        end
      end
    end
  end
end
