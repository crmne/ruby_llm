# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # Transcription dialect for the xAI Voice API. The /v1/stt endpoint is
      # model-less multipart with the audio file last in the form; giving
      # speaker names turns on diarization, which labels each word with a
      # numeric speaker index.
      module Transcription
        module_function

        def transcription_url
          'stt'
        end

        # rubocop:disable Lint/UnusedMethodArgument
        def render_transcription_payload(file_part, model:, language:, format: nil, speaker_names: nil,
                                         speaker_references: nil, provider_options: {}, prompt: nil,
                                         temperature: nil)
          payload = {}
          payload[:language] = language if language
          payload[:diarize] = true if speaker_names
          payload.merge(provider_options).merge(file: file_part)
        end
        # rubocop:enable Lint/UnusedMethodArgument

        def parse_transcription_response(response, model:)
          data = response.body

          RubyLLM::Transcription.new(
            text: data['text'],
            model: model,
            language: data['language'],
            duration: data['duration'],
            segments: data['channels'],
            words: data['words']
          )
        end
      end
    end
  end
end
