# frozen_string_literal: true

module RubyLLM
  module Providers
    # ElevenLabs API integration. ElevenLabs is a speech company, so this
    # provider covers text to speech and speech to text only. Chat,
    # embeddings, and image generation have no ElevenLabs endpoint and
    # raise NotImplementedError.
    class ElevenLabs < Provider
      protocol :elevenlabs, Protocols::ElevenLabs

      def api_base
        @config.elevenlabs_api_base || 'https://api.elevenlabs.io'
      end

      def headers
        { 'xi-api-key' => @config.elevenlabs_api_key }
      end

      class << self
        def configuration_options
          %i[elevenlabs_api_key elevenlabs_api_base]
        end

        def configuration_requirements
          %i[elevenlabs_api_key]
        end
      end
    end
  end
end
