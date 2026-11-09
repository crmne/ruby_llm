# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Meta
      # Muse Voice Transcribe on /v1/asr/transcribe. The settings travel as a
      # JSON multipart part beside the WAV audio. The mode decides what comes
      # back: one transcript by default, timed turns with ENDPOINTING, and
      # turns labelled with a speaker with DIARIZATION. Accepting an event
      # stream returns the same events as Meta's realtime endpoint.
      # https://dev.meta.ai/docs/speech-to-text
      module Transcription
        STREAM_HEADERS = { 'Accept' => 'text/event-stream' }.freeze

        def rejected_options(operation)
          operation == :transcribe ? %i[format temperature speaker_references named_speakers] : super
        end

        def render_transcription_options(timestamps:, streaming:, **)
          options = streaming ? { emitAudioProgress: false } : {}
          return options if timestamps.nil?
          unless Array(timestamps).map(&:to_s) == ['segment']
            raise ArgumentError, 'Meta transcription timestamps must be segment'
          end

          options.merge(mode: 'ENDPOINTING')
        end

        def transcription_url
          'asr/transcribe'
        end

        def render_transcription_payload(file_part, model:, language:, speaker_names: nil, provider_options: {},
                                         prompt: nil, **)
          settings = { model:, audioEncoding: 'WAV', languageBias: language && Array(language),
                       keywords: prompt && Array(prompt) }.compact
          settings = settings.merge(provider_options.transform_keys(&:to_sym))
          settings[:mode] = 'DIARIZATION' if speaker_names
          { request: Faraday::Multipart::ParamPart.new(JSON.generate(settings), 'application/json'),
            audio: render_transcription_audio(file_part) }
        end

        def parse_transcription_response(response, model:)
          data = response.body
          duration = data['audioDurationMs'] && (data['audioDurationMs'] / 1000.0)
          turns = data['turns'].to_a

          RubyLLM::Transcription.new(
            text: data['transcript'], model:, duration:, audio_seconds: duration,
            segments: turns.empty? ? nil : turns.map { |turn| parse_transcription_turn(turn) }
          )
        end

        def stream_transcription(payload, model:, &)
          stream = Stream.new(model:, &)
          stream_events(transcription_url, payload, STREAM_HEADERS) { |event| stream.process(event) }
          stream.finish
        end

        private

        # Meta answers "Malformed multipart body" to a part with its own
        # Content-Length, which a file part always carries.
        def render_transcription_audio(file_part)
          audio = file_part.io.read
          file_part.io.close
          Faraday::Multipart::ParamPart.new(audio, file_part.content_type)
        end

        def parse_transcription_turn(turn)
          turn.merge('text' => turn['transcript'], 'start' => turn['startMs'] / 1000.0, 'end' => turn['endMs'] / 1000.0)
        end
      end
    end
  end
end
