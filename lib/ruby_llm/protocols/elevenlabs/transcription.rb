# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ElevenLabs
      # Transcription dialect for the ElevenLabs speech-to-text API. The
      # request is multipart with the model id in the form, and giving
      # speaker names turns on diarization and caps the speaker count at
      # the number of names.
      module Transcription
        # rubocop:disable Lint/UnusedMethodArgument
        def render_transcription_payload(file_part, model:, language:, format: nil, speaker_names: nil,
                                         speaker_references: nil, provider_options: {}, prompt: nil,
                                         temperature: nil)
          payload = {
            model_id: model,
            file: file_part,
            language_code: language,
            temperature: temperature,
            timestamps_granularity: format
          }.compact

          if speaker_names
            payload[:diarize] = true
            payload[:num_speakers] = speaker_names.size
          end

          payload.merge(provider_options)
        end
        # rubocop:enable Lint/UnusedMethodArgument

        def transcription_url
          'v1/speech-to-text'
        end

        def parse_transcription_response(response, model:)
          data = response.body

          RubyLLM::Transcription.new(
            text: data['text'],
            model: model,
            language: data['language_code'],
            duration: data['audio_duration_secs'],
            words: data['words']
          )
        end
      end
    end
  end
end
