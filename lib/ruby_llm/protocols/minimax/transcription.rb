# frozen_string_literal: true

module RubyLLM
  module Protocols
    class MiniMax
      # Speech to text on v1/speech_to_text. The language hint travels as a
      # request header, and verbose_json is the format that carries timed,
      # speaker-labelled segments.
      module Transcription
        TIMESTAMP_LEVELS = { segment: nil, word: 'word' }.freeze

        def rejected_options(operation)
          operation == :transcribe ? %i[temperature prompt speaker_references named_speakers] : super
        end

        def render_transcription_options(timestamps:, format: nil, **)
          return {} if timestamps.nil?

          level = timestamps.respond_to?(:to_sym) ? timestamps.to_sym : timestamps
          unless TIMESTAMP_LEVELS.key?(level)
            raise ArgumentError, 'MiniMax transcription timestamps must be word or segment'
          end

          { response_format: format || 'verbose_json', timestamp_level: TIMESTAMP_LEVELS[level] }.compact
        end

        def transcription_url
          media_url('v1/speech_to_text')
        end

        def transcribe(audio_file, model:, language:, format: nil, speaker_names: nil,
                       provider_options: {}, **, &block)
          headers = language ? { 'language' => language.to_s } : {}
          track_usage(:transcription) do
            payload = render_transcription_payload(build_audio_file_part(audio_file), model:, format:, speaker_names:,
                                                                                      provider_options:)
            next stream_transcription(payload, model:, language:, headers:, &block) if block

            response = @connection.post(transcription_url, payload, usage: @usage_tracker) do |request|
              request.headers.merge!(headers)
            end
            parse_transcription_response(response, model:, language:, word_level: payload[:timestamp_level] == 'word')
          end
        end

        def render_transcription_payload(file_part, model:, format: nil, speaker_names: nil, provider_options: {}, **)
          payload = { model: model, response_format: format || ('verbose_json' if speaker_names) }.compact
          payload.merge(provider_options.transform_keys(&:to_sym)).except(:file).merge(file: file_part)
        end

        def parse_transcription_response(response, model:, language: nil, word_level: false)
          data = response.body
          return RubyLLM::Transcription.new(text: data, model:, language:) if data.is_a?(String)

          RubyLLM::Transcription.new(
            text: data['text'], model:, language:, duration: data['duration'], audio_seconds: data['duration'],
            segments: (data['segments'] unless word_level), words: (data['segments'] if word_level)
          )
        end

        def stream_transcription(payload, model:, language: nil, headers: {}, &block)
          text = +''
          duration = nil
          stream_events(transcription_url, payload.merge(stream: 'true'), headers) do |event|
            delta = event['delta'].to_s
            text << delta
            duration = event['duration'] || duration
            block.call(transcription_chunk(:delta, delta:, raw: event)) unless delta.empty?
            block.call(transcription_chunk(:done, text: text.dup, raw: event)) if event['finish']
          end
          RubyLLM::Transcription.new(text:, model:, language:, duration:, audio_seconds: duration)
        end

        private

        def transcription_chunk(type, **attributes)
          RubyLLM::TranscriptionChunk.new(type:, **attributes)
        end
      end
    end
  end
end
