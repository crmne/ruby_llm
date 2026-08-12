# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ElevenLabs
      # Speech dialect for the ElevenLabs text-to-speech API. The voice id
      # is a path segment and the container is an output_format query
      # value, so the endpoint cannot be named without the voice and format
      # the caller asked for. The response is raw audio bytes.
      module Speech
        DEFAULT_VOICE = 'JBFqnCBsd6RMkjVDRZzb'
        DEFAULT_OUTPUT_FORMAT = 'mp3_44100_128'

        OUTPUT_FORMATS = {
          'alaw' => 'alaw_8000',
          'mp3' => 'mp3_44100_128',
          'opus' => 'opus_48000_128',
          'pcm' => 'pcm_44100',
          'ulaw' => 'ulaw_8000',
          'wav' => 'wav_44100'
        }.freeze

        def speak(input, model:, voice:, format:, provider_options: {})
          track_usage(:speech) do
            payload = render_speech_payload(input, model:, voice:, format:, provider_options:)
            response = @connection.post speech_url(voice:, format:), payload, usage: @usage_tracker
            parse_speech_response(response, model:, voice:, format:)
          end
        end

        def speech_url(voice: nil, format: nil)
          "v1/text-to-speech/#{voice || DEFAULT_VOICE}?output_format=#{output_format_for(format)}"
        end

        def render_speech_payload(input, model:, voice: nil, format: nil, provider_options: {}) # rubocop:disable Lint/UnusedMethodArgument
          Utils.deep_merge({ text: input, model_id: model }, provider_options)
        end

        def parse_speech_response(response, model:, voice:, format:)
          RubyLLM::Speech.new(
            data: response.body,
            model: model,
            voice: voice || DEFAULT_VOICE,
            format: container_for(format)
          )
        end

        def output_format_for(format)
          return DEFAULT_OUTPUT_FORMAT unless format

          OUTPUT_FORMATS.fetch(format.to_s, format.to_s)
        end

        def container_for(format)
          output_format_for(format).split('_').first
        end
      end
    end
  end
end
