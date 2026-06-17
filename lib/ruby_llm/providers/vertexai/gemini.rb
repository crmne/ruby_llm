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

        private

        def transcription_url(model)
          "#{@provider.model_path(model)}:generateContent"
        end
      end
    end
  end
end
