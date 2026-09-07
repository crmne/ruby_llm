# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      module FileTranscription # :nodoc: all
        def transcribe(audio_file, model:, language:, format: nil, speaker_names: nil,
                       speaker_references: nil, provider_options: {}, prompt: nil, temperature: nil)
          raise_transcription_streaming_unsupported if block_given?
          validate_transcription_request(format:, speaker_references:, temperature:)
          attachments = Attachment.wrap(audio_file, config: @config)
          unless attachments.one? && attachments.first.audio?
            raise ArgumentError, 'Dedicated transcription requires exactly one audio file'
          end

          track_usage(:transcription) do
            payload = render_transcription_payload(attachments.first, model:, language:, speaker_names:,
                                                                      provider_options:, prompt:)
            response = @connection.post(transcription_url(model), payload, usage: @usage_tracker)
            parse_transcription_response(response, model:)
          end
        end

        def validate_transcription_request(format:, speaker_references:, temperature:)
          return unless format || speaker_references || temperature

          raise ArgumentError, 'Dedicated transcription does not accept format, speaker references, or temperature'
        end
      end
    end
  end
end
