# frozen_string_literal: true

require 'base64'

module RubyLLM
  module Protocols
    class Gemini
      # Speech generation methods for the Gemini API implementation
      module Speech
        def speech_url(model:)
          "models/#{model}:generateContent"
        end

        def render_speech_payload(input, model:, voice:, format:, params: {}, **options) # rubocop:disable Lint/UnusedMethodArgument,Metrics/ParameterLists
          RubyLLM.logger.debug { "Ignoring speech format #{format}. Gemini returns PCM audio." } if format

          payload = {
            contents: [
              {
                role: 'user',
                parts: [
                  { text: input }
                ]
              }
            ],
            generationConfig: {
              responseModalities: ['AUDIO'],
              speechConfig: {
                voiceConfig: {
                  prebuiltVoiceConfig: {
                    voiceName: voice || 'Kore'
                  }
                }
              }
            },
            model: model
          }

          Utils.deep_merge(payload, params)
        end

        def parse_speech_response(response, model:, voice:, format:) # rubocop:disable Lint/UnusedMethodArgument
          audio = response.body.dig('candidates', 0, 'content', 'parts', 0, 'inlineData', 'data')
          raise Error, 'Unexpected response format from Gemini speech generation API' unless audio

          RubyLLM::Speech.new(
            data: Base64.decode64(audio),
            model: model,
            voice: voice || 'Kore',
            format: 'pcm'
          )
        end
      end
    end
  end
end
