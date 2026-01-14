# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Speech generation methods for the OpenAI API integration
      module Speech
        module_function

        def speech_url
          'audio/speech'
        end

        def render_speech_payload(input, model:, voice:)
          {
            model: model,
            input: input,
            voice: voice
          }
        end

        def parse_speech_response(response, model:)
          data = response.body
          RubyLLM::Speech.new(
            model: model,
            data: data
          )
        end
      end
    end
  end
end
