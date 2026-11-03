# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # Speech generation methods for the OpenAI API integration
      module Speech
        def speak(input, **, &)
          @speech_characters = input.to_s.length
          super
        end

        module_function

        def speech_url(**)
          'audio/speech'
        end

        def stream_speech(payload, model:, voice:, format:, &)
          stream_speech_response(speech_url(model:), payload, model:, voice:, format:, &)
        end

        def render_speech_payload(input, model:, voice:, format:, provider_options: {})
          {
            model: model,
            input: input,
            voice: voice || 'alloy',
            response_format: format
          }.compact.merge(provider_options)
        end

        def parse_speech_response(response, model:, voice:, format:)
          resolved_format = (format || 'mp3').to_s

          RubyLLM::Speech.new(
            data: response.body,
            model: model,
            voice: voice || 'alloy',
            format: resolved_format,
            characters: @speech_characters
          )
        end
      end
    end
  end
end
