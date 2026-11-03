# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # Transcription dialect for the xAI Voice API. The /v1/stt endpoint is
      # multipart with the audio file last in the form; requesting speaker
      # labels turns on diarization, which labels each word with a numeric
      # speaker index.
      module Transcription
        # grok-stt is the registry's name for the service; the API has its own.
        MODEL_IDS = { 'grok-stt' => 'grok-voice-transcribe-2.0' }.freeze

        def render_transcription_options(timestamps:, **)
          return {} if timestamps.nil? || timestamps == :word

          raise ArgumentError, 'xAI transcription timestamps must be word'
        end

        def rejected_options(operation)
          operation == :transcribe ? %i[format temperature prompt speaker_references named_speakers] : super
        end

        module_function

        def transcription_url
          'stt'
        end

        def render_transcription_payload(file_part, model:, language:, speaker_names: nil, provider_options: {}, **)
          payload = { model: MODEL_IDS.fetch(model, model) }
          payload[:language] = language if language
          payload[:diarize] = true if speaker_names
          payload.merge(provider_options.transform_keys(&:to_sym)).except(:file).merge(file: file_part)
        end

        def parse_transcription_response(response, model:)
          data = response.body

          RubyLLM::Transcription.new(
            text: data['text'],
            model: model,
            language: data['language'],
            duration: data['duration'],
            audio_seconds: data['duration'],
            segments: data['channels'],
            words: data['words']
          )
        end
      end
    end
  end
end
