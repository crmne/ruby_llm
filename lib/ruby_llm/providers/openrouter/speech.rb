# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenRouter
      # Speech generation methods for the OpenRouter API integration.
      # Voices are model-specific across OpenRouter's TTS catalog, so no
      # default voice is assumed.
      module Speech
        module_function

        def render_speech_payload(input, model:, voice:, format:, provider_options: {})
          {
            model: model,
            input: input,
            voice: voice,
            response_format: format || 'mp3'
          }.compact.merge(provider_options)
        end

        def parse_speech_response(response, model:, voice:, format:)
          RubyLLM::Speech.new(
            data: response.body,
            model: model,
            voice: voice,
            format: (format || 'mp3').to_s
          )
        end
      end
    end
  end
end
