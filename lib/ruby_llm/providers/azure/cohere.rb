# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Azure endpoints and deployment names for the native Cohere APIs.
      class Cohere < Protocols::Cohere
        abstract :render_payload, :completion_url, :models_url, :ocr_url, :transcription_url, :tokenization_url
        undef_method :create_batch, :find_batch, :cancel_batch, :batch_results

        EMBEDDING_MODEL_ALIASES = {
          'Cohere-embed-v3-english' => 'embed-english-v3.0',
          'Cohere-embed-v3-multilingual' => 'embed-multilingual-v3.0'
        }.freeze
        private_constant :EMBEDDING_MODEL_ALIASES

        def embedding_url(...)
          @provider.azure_cohere_url('embed')
        end

        def rerank_url
          @provider.azure_cohere_url('rerank')
        end

        private

        def separate_image_embeddings?(model)
          super(EMBEDDING_MODEL_ALIASES.fetch(model, model))
        end
      end
    end
  end
end
