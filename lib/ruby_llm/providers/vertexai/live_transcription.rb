# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI
      class LiveTranscription < Protocols::Gemini::LiveTranscription # :nodoc: all
        def validate_transcription_request(...)
          super
          return if @config.vertexai_location == 'global'

          raise ArgumentError, 'Vertex AI Live transcription requires vertexai_location = "global"'
        end

        def transcription_model_name(model)
          @provider.model_path(model)
        end

        def websocket_service
          'google.cloud.aiplatform.v1beta1.LlmBidiService/BidiGenerateContent'
        end
      end
    end
  end
end
