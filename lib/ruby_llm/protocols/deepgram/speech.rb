# frozen_string_literal: true

require 'uri'

module RubyLLM
  module Protocols
    class Deepgram
      # Speech dialect for the Deepgram text-to-speech API. Deepgram names
      # the voice inside the model id, so aura-2-thalia-en is the Thalia
      # voice of Aura 2: asking for a +voice:+ swaps that segment of the
      # model id. The container is an encoding query value, the body carries
      # only the text, and the response is raw audio bytes.
      module Speech
        DEFAULT_FORMAT = 'mp3'

        # RubyLLM format names in Deepgram's encoding vocabulary. Deepgram
        # wraps linear16 in a WAV header unless the container is turned off,
        # and the compressed encodings carry their own.
        OUTPUT_FORMATS = {
          'aac' => { encoding: 'aac' },
          'alaw' => { encoding: 'alaw', container: 'wav' },
          'flac' => { encoding: 'flac' },
          'mp3' => { encoding: 'mp3' },
          'mulaw' => { encoding: 'mulaw', container: 'wav' },
          'opus' => { encoding: 'opus' },
          'pcm' => { encoding: 'linear16', container: 'none' },
          'wav' => { encoding: 'linear16', container: 'wav' }
        }.freeze

        def speak(input, model:, voice:, format:, provider_options: {})
          track_usage(:speech) do
            spoken_model = speech_model_for(model, voice)
            payload = render_speech_payload(input, model: spoken_model, voice:, format:)
            response = @connection.post speech_url(model: spoken_model, format:, provider_options:), payload,
                                        usage: @usage_tracker
            parse_speech_response(response, model: spoken_model, voice: voice_for(spoken_model), format:)
          end
        end

        def speech_url(model:, format: nil, provider_options: {})
          "v1/speak?#{URI.encode_www_form(speech_params(model:, format:, provider_options:))}"
        end

        def speech_params(model:, format: nil, provider_options: {})
          { model: model }.merge(OUTPUT_FORMATS.fetch(format_for(format), encoding: format_for(format)))
                          .merge(provider_options).compact
        end

        # rubocop:disable Lint/UnusedMethodArgument
        def render_speech_payload(input, model:, voice: nil, format: nil, provider_options: {})
          { text: input }
        end
        # rubocop:enable Lint/UnusedMethodArgument

        def parse_speech_response(response, model:, voice:, format:)
          RubyLLM::Speech.new(
            data: response.body,
            model: model,
            voice: voice,
            format: format_for(format)
          )
        end

        # Puts +voice+ into the voice segment of +model+, so Aura 2 with
        # voice 'zeus' is aura-2-zeus-en. A voice that already names a whole
        # model is used as it stands.
        def speech_model_for(model, voice)
          return model unless voice

          segments = model.to_s.split('-')
          return voice if voice.include?('-') || segments.size < 3

          (segments[0..-3] + [voice, segments[-1]]).join('-')
        end

        # The voice segment of a Deepgram model id, so aura-2-thalia-en
        # speaks as 'thalia'.
        def voice_for(model)
          segments = model.to_s.split('-')
          segments[-2] if segments.size >= 3
        end

        def format_for(format)
          (format || DEFAULT_FORMAT).to_s
        end
      end
    end
  end
end
