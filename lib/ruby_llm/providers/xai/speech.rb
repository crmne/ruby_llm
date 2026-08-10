# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # Speech dialect for the xAI Voice API. The /v1/tts endpoint is
      # model-less: it takes text, voice_id, and a required language
      # (defaulted to auto-detection) and returns raw audio bytes.
      module Speech
        module_function

        def speech_url(model:) # rubocop:disable Lint/UnusedMethodArgument
          'tts'
        end

        def render_speech_payload(input, model:, voice:, format:, provider_options: {}) # rubocop:disable Lint/UnusedMethodArgument
          payload = {
            text: input,
            voice_id: voice,
            language: 'auto'
          }.compact
          payload[:output_format] = { codec: format.to_s } if format
          Utils.deep_merge(payload, provider_options)
        end

        def parse_speech_response(response, model:, voice:, format:)
          RubyLLM::Speech.new(
            data: response.body,
            model: model,
            voice: voice || 'eve',
            format: (format || 'mp3').to_s
          )
        end
      end
    end
  end
end
