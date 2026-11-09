# frozen_string_literal: true

module RubyLLM
  module Protocols
    class MiniMax
      # Synchronous text to speech on v1/t2a_v2, which returns the audio
      # hex-encoded inside a JSON body.
      module Speech
        DEFAULT_VOICE = 'English_expressive_narrator'
        DEFAULT_FORMAT = 'mp3'

        def speech_url(**)
          media_url('v1/t2a_v2')
        end

        def render_speech_payload(input, model:, voice: nil, format: nil, provider_options: {})
          payload = {
            model: model,
            text: input,
            stream: false,
            output_format: 'hex',
            voice_setting: { voice_id: voice || DEFAULT_VOICE },
            audio_setting: { format: (format || DEFAULT_FORMAT).to_s }
          }
          Support::Utils.deep_merge(payload, provider_options).tap do |rendered|
            @effective_voice = Support::Utils.deep_symbolize_keys(rendered).dig(:voice_setting, :voice_id)
          end
        end

        def parse_speech_response(response, model:, voice:, format:)
          audio = response.body.dig('data', 'audio')
          raise Error.new('MiniMax did not return audio', response:) unless audio

          RubyLLM::Speech.new(
            data: decode_speech_audio(audio),
            model: model,
            voice: @effective_voice || voice || DEFAULT_VOICE,
            format: response.body.dig('extra_info', 'audio_format') || (format || DEFAULT_FORMAT).to_s,
            characters: response.body.dig('extra_info', 'usage_characters')
          )
        end

        private

        def decode_speech_audio(audio)
          return [audio].pack('H*') unless audio.start_with?('http')

          Transport::Connection.download(audio, @config)
        end
      end
    end
  end
end
