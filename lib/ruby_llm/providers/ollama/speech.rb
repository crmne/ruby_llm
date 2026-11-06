# frozen_string_literal: true

module RubyLLM
  module Providers
    class Ollama
      # Ollama's dialect of speech generation. Its voices come from each model,
      # so a call with no voice leaves the choice to the model, and it answers
      # with WAV unless asked for PCM.
      module Speech
        DEFAULT_VOICE = 'default'
        DEFAULT_FORMAT = 'wav'

        def render_speech_payload(input, model:, voice:, format:, provider_options: {})
          { model:, input:, voice:, response_format: format }.compact.merge(provider_options)
        end

        def parse_speech_response(response, model:, voice:, format:)
          RubyLLM::Speech.new(data: response.body, model:, voice: voice || DEFAULT_VOICE,
                              format: (format || DEFAULT_FORMAT).to_s, characters: @speech_characters)
        end
      end
    end
  end
end
