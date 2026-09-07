# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Speech dialect for the Mistral API, which requires a voice from its own
      # catalog and returns JSON with base64 audio instead of raw bytes.
      module Speech
        module_function

        def stream_speech(payload, model:, voice:, format:)
          audio = +''.b
          final = nil
          stream_events(speech_url(model:), payload.merge(stream: true)) do |event|
            case event['type']
            when 'speech.audio.delta'
              data = Base64.strict_decode64(event.fetch('audio_data'))
              audio << data
              yield SpeechChunk.new(data:, format: format || 'mp3') unless data.empty?
            when 'speech.audio.done'
              final = event
            end
          end
          raise Error, 'Mistral speech stream ended before its completion event' unless final

          usage = final['usage'] || {}
          RubyLLM::Speech.new(data: audio, model:, voice:, format: format || 'mp3',
                              input_tokens: usage['prompt_tokens'], output_tokens: usage['completion_tokens'])
        end

        def render_speech_payload(input, model:, voice:, format:, provider_options: {})
          {
            model: model,
            input: input,
            voice_id: voice,
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
