# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI < Provider
      # The Gemini protocol over Vertex AI endpoints.
      class Gemini < Protocols::Gemini
        include VertexAI::Embeddings
        include VertexAI::Models

        def completion_url
          "#{@provider.model_path(@model.id)}:generateContent"
        end

        def stream_url
          "#{@provider.model_path(@model.id)}:streamGenerateContent?alt=sse"
        end

        def count_tokens_url
          "#{@provider.model_path(@model.id)}:countTokens"
        end

        def render_count_tokens_payload(messages, **options)
          count_tokens_request(messages, **options)
        end

        def caches_url
          "#{@provider.location_path}/cachedContents"
        end

        def cache_name(name)
          name = name.name if name.is_a?(CachedContent)
          name.to_s.include?('/') ? name.to_s : "#{caches_url}/#{name}"
        end

        def cache_model_name(model_id)
          @provider.model_path(model_id)
        end

        def images_url(with: nil, mask: nil) # rubocop:disable Lint/UnusedMethodArgument
          id = model_id(@model)

          "#{@provider.model_path(id)}:#{image_endpoint_action(id)}"
        end

        def speech_url(model:)
          "#{@provider.model_path(model)}:generateContent"
        end

        private

        def transcription_url(model)
          "#{@provider.model_path(model)}:generateContent"
        end
      end
    end
  end
end
