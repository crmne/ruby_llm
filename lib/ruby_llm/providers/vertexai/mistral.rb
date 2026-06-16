# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI < Provider
      # Mistral's models speak their own dialect of Chat Completions over Vertex AI
      # rawPredict endpoints. We reuse Mistral's dialect wholesale and only swap the URLs.
      class Mistral < Providers::Mistral::ChatCompletions
        # The Mistral model families Vertex AI serves directly. Shared by the
        # registry (which models to list) and protocol_for (where to route them).
        MODELS = /\A(mistral|ministral|codestral|magistral|mathstral|pixtral|devstral|voxtral)/

        def completion_url
          "#{@provider.model_path(@model.id, publisher: 'mistralai')}:rawPredict"
        end

        def stream_url
          "#{@provider.model_path(@model.id, publisher: 'mistralai')}:streamRawPredict"
        end
      end
    end
  end
end
