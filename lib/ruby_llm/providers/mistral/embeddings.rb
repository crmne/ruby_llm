module RubyLLM
  module Providers
    module Mistral
      # Handles text embeddings for Mistral models
      module Embeddings
        module_function

        # Accept optional `model:` keyword argument to match Provider interface call
        def embedding_url(model: nil)
          # NOTE: The model argument is accepted for interface compatibility but not used,
          # as the Mistral embedding endpoint isn't model-specific in the URL.
          "#{Mistral.api_base(RubyLLM.config)}/embeddings"
        end

        # Accept optional `dimensions:` keyword argument for interface compatibility
        def render_embedding_payload(text, model:, dimensions: nil)
          # NOTE: dimensions is ignored as Mistral API doesn't support it.
          {
            model: model,
            input: text,
          }
        end

        # Accept optional `model:` keyword argument for interface compatibility
        def parse_embedding_response(response, model: nil)
          # NOTE: model argument is ignored; we get it from the response body.
          data = response.body
          model_id = data["model"]
          input_tokens = data.dig("usage", "prompt_tokens") || 0

          # Get the embeddings from the response
          vectors = data["data"].map { |d| d["embedding"] }

          # If we only got one embedding, return it as a single vector
          vectors = vectors.first if vectors.size == 1

          Embedding.new(
            vectors: vectors,
            model: model_id, # Use model_id from response
            input_tokens: input_tokens,
          )
        end
      end
    end
  end
end
