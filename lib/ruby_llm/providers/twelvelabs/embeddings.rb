# frozen_string_literal: true

module RubyLLM
  module Providers
    class TwelveLabs
      # Embeddings methods for the TwelveLabs (Marengo) API.
      #
      # TwelveLabs exposes a single multimodal embedding model family (Marengo).
      # The text path is synchronous and returns a 512-dimensional float vector
      # per input. The endpoint expects `multipart/form-data` rather than JSON,
      # so payloads are built from `Faraday::Multipart::ParamPart`s to engage
      # Faraday's multipart middleware.
      module Embeddings
        module_function

        def embedding_url(...)
          'embed'
        end

        def render_embedding_payload(text, model:, dimensions:) # rubocop:disable Lint/UnusedMethodArgument
          inputs = text.is_a?(Array) ? text : [text]
          raise Error.new(nil, 'TwelveLabs embeddings accept a single text input') if inputs.size > 1

          {
            model_name: param_part(model),
            text: param_part(inputs.first.to_s)
          }
        end

        def parse_embedding_response(response, model:, text:)
          segments = response.body.dig('text_embedding', 'segments') || []
          vectors = segments.first&.fetch('float', nil)
          vectors = [vectors] if text.is_a?(Array)

          Embedding.new(vectors:, model: response.body['model_name'] || model, input_tokens: 0)
        end

        def param_part(value)
          require 'faraday/multipart'
          Faraday::Multipart::ParamPart.new(value.to_s, 'text/plain')
        end
      end
    end
  end
end
