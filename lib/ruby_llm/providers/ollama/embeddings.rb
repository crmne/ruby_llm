# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Embeddings methods for the Ollama API integration
      module Embeddings
        # Must be public for Provider module
        def embed(text, model:) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          payload = {
            model: model,
            input: format_text_for_embedding(text)
          }

          url = 'api/embed'
          response = post(url, payload)

          Embedding.new(
            vectors: response.body['embeddings'],
            model: model,
            # only available when passing a single string input
            input_tokens: response.body['prompt_eval_count'] || 0
          )
        end

        private

        def format_text_for_embedding(text)
          # Ollama supports either a string or a string array here
          unless text.is_a?(Array) || text.is_a?(String)
            raise NotImplementedException, "unsupported argument for Ollama embedding: #{text.class}"
          end

          text
        end
      end
    end
  end
end
