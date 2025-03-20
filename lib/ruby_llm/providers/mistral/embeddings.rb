module RubyLLM
  module Providers
    module Mistral
      # Handles text embeddings for Mistral models
      module Embeddings
        module_function

        def embedding_url
          "#{Mistral.api_base}/embeddings"
        end

        def render_embedding_payload(text, model:)
          {
            model: model,
            input: text,
          }
        end

        def parse_embedding_response(response)
          data = response.body
          model_id = data["model"]
          input_tokens = data.dig("usage", "prompt_tokens") || 0

          # Get the embeddings from the response
          vectors = data["data"].map { |d| d["embedding"] }

          # If we only got one embedding, return it as a single vector
          vectors = vectors.first if vectors.size == 1

          Embedding.new(
            vectors: vectors,
            model: model_id,
            input_tokens: input_tokens,
          )
        end
      end
    end
  end
end
