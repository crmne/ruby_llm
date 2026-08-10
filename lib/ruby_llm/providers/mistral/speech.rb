# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Speech dialect for the Mistral API, which requires a voice from its own
      # catalog and returns JSON with base64 audio instead of raw bytes.
      module Speech
        module_function

        def render_speech_payload(input, model:, voice:, format:, provider_options: {})
          {
            model: model,
            input: input,
            voice: voice,
            response_format: format
          }.compact.merge(provider_options)
        end

        def parse_speech_response(response, model:, voice:, format:)
          RubyLLM::Speech.new(
            data: Base64.decode64(response.body['audio_data'].to_s),
            model: model,
            voice: voice,
            format: (format || 'mp3').to_s
          )
        end
      end
    end
  end
end
