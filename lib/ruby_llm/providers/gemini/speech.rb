# frozen_string_literal: true

module RubyLLM
  module Providers
    class Gemini
      # Speech generation methods for the Gemini API integration
      module Speech
        module_function

        def speech_url
          "models/#{@model}:generateContent"
        end

        def render_speech_payload(input, model:, voice:)
          @model = model
          {
            contents: [{
              role: 'user',
              parts: [{ text: input }]
            }],
            generationConfig: {
              responseModalities: ['AUDIO'],
              speechConfig: {
                voiceConfig: {
                  prebuiltVoiceConfig: {
                    voiceName: voice
                  }
                }
              }
            },
            model: model
          }
        end

        def parse_speech_response(response, model:)
          base64_audio = response.body['candidates'][0]['content']['parts'][0]['inlineData']['data']
          pcm_data = Base64.decode64(base64_audio)

          RubyLLM::Speech.new(
            model: model,
            data: pcm_data
          )
        end
      end
    end
  end
end
