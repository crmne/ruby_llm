# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Embeddings methods for the Ollama API integration
      module Embeddings
        module_function

        def embedding_url
          'api/embed'
        end

        def render_embedding_payload(text, model:)
          {
            model: model,
            input: format_text_for_embedding(text)
          }
        end

        def parse_embedding_response(response)
          vectors = response.body['embeddings']
          model_id = response.body['model']
          input_tokens = response.body['prompt_eval_count'] || 0
          vectors = vectors.first if vectors.size == 1

          Embedding.new(
            vectors: vectors,
            model: model_id,
            # only available when passing a single string input
            input_tokens: input_tokens
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
