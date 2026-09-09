# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Audio endpoints for Azure OpenAI deployments and the v1 API.
      module Audio
        def speech_url(model:)
          @provider.azure_media_url(super)
        end

        def transcription_url
          @provider.azure_media_url(super)
        end
      end
    end
  end
end
