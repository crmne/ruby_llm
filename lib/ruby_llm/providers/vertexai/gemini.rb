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

        def images_url(with: nil, mask: nil) # rubocop:disable Lint/UnusedMethodArgument
          id = model_id(@model)

          "#{@provider.model_path(id)}:#{image_endpoint_action(id)}"
        end

        private

        def transcription_url(model)
          "#{@provider.model_path(model)}:generateContent"
        end
      end
    end
  end
end
