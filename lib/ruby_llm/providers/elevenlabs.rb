# frozen_string_literal: true

module RubyLLM
  module Providers
    # Integrates ElevenLabs speech, transcription, ElevenAgents, and Image & Video APIs.
    class ElevenLabs < Provider
      protocol :elevenlabs, Protocols::ElevenLabs
      protocol :flows, Protocols::ElevenLabs::Flows
      protocol :files, Protocols::ElevenLabs::Assets

      def resolve_protocol(name, model, operation: nil, **options)
        name ||= :flows if %i[paint animate].include?(operation)
        super
      end

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
