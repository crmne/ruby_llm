# frozen_string_literal: true

module RubyLLM
  module Protocols
    module OpenRouter
      module Transcription # :nodoc: all
        def transcribe(audio_file, model:, language:, format: nil, speaker_names: nil,
                       speaker_references: nil, provider_options: {}, prompt: nil, temperature: nil, &block)
          raise_transcription_streaming_unsupported if block
          validate_transcription_options(format:, speaker_names:, speaker_references:, prompt:)
          track_usage(:transcription) do
            attachment = audio_file.is_a?(Attachment) ? audio_file : Attachment.new(audio_file, config: @config)
            payload = {
              model:, input_audio: { data: Base64.strict_encode64(attachment.content), format: attachment.format },
              language:, temperature:, response_format: format || (speaker_names ? 'verbose_json' : 'json')
            }.compact
            if speaker_names
              payload[:provider] =
                { options: { azure: { diarization: { enabled: true } }, deepgram: { diarize: true } } }
            end
            response = @connection.post(transcription_url, Support::Utils.deep_merge(payload, provider_options),
                                        usage: @usage_tracker)
            parse_transcription_response(response, model:)
          end
        end

        private

        def validate_transcription_options(format:, speaker_names:, speaker_references:, prompt:)
          if speaker_references || (speaker_names && !speaker_names.empty?)
            raise ArgumentError,
                  'OpenRouter accepts speaker_names: [] for diarization, but not speaker identities or reference audio'
          end
          if prompt
            raise ArgumentError,
                  'OpenRouter transcription ignores prompt; use provider_options for backend hints'
          end
          validate_transcription_format(format, diarization: !speaker_names.nil?)
        end

        def validate_transcription_format(format, diarization:)
          formats = diarization ? ['verbose_json'] : %w[json verbose_json]
          return if format.nil? || formats.include?(format.to_s)

          raise ArgumentError,
                'OpenRouter transcription accepts json or verbose_json; diarization requires verbose_json'
        end
      end
    end
  end
end
