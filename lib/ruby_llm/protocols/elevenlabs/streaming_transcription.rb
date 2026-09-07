# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ElevenLabs
      module StreamingTranscription # :nodoc: all
        SAMPLE_RATES = [8000, 16_000, 22_050, 24_000, 44_100, 48_000].freeze

        def stream_transcription(payload, model:, &block)
          validate_streaming_transcription(payload)
          audio = RubyLLM::Transcription::WavAudio.new(payload.fetch(:file).io.read)
          raise ArgumentError, 'Streaming transcription requires non-empty audio' if audio.data.empty?

          audio_format = streaming_audio_format(audio)
          url = streaming_transcription_url(payload, audio_format:)
          @usage_tracker.start
          expected_commits = (audio.data.bytesize.to_f / transcription_segment_bytes(audio)).ceil
          transcripts = collect_transcription(url, audio, expected_commits, &block)
          result = build_streaming_transcription(transcripts, audio, model:)
          block.call(TranscriptionChunk.new(type: TranscriptionChunk::DONE, text: result.text, raw: transcripts.last))
          result
        ensure
          payload[:file]&.io&.close
        end

        def collect_transcription(url, audio, expected_commits, &block)
          transcripts = []
          commits = Queue.new
          Transport::WebsocketConnection.open(url, headers: @provider.headers, config: @config) do |socket|
            write = ->(connection) { send_transcription_audio(connection, audio, commits) }
            socket.each_message(write:) do |message|
              event = JSON.parse(message)
              transcript = process_transcription_event(event, prefix: transcripts.any?, &block)
              next unless transcript

              transcripts << transcript
              commits << true
              socket.close if transcripts.size == expected_commits
            end
          end
          unless transcripts.size == expected_commits && transcripts.any?
            raise Error, 'ElevenLabs transcription ended before its committed transcript'
          end

          transcripts
        end

        def build_streaming_transcription(transcripts, audio, model:)
          RubyLLM::Transcription.new(
            text: transcripts.map { |item| item.fetch('text') }.join(' '), model:,
            duration: audio.duration, language: transcripts.last['language_code'],
            words: transcripts.flat_map { |item| item['words'] || [] }
          )
        end

        def validate_streaming_transcription(payload)
          unsupported = payload.keys & %i[diarize num_speakers temperature timestamps_granularity]
          unless unsupported.empty?
            raise ArgumentError, "ElevenLabs streaming transcription does not accept #{unsupported.join(', ')}"
          end

          if payload.fetch(:commit_strategy, 'manual') != 'manual' || payload[:include_timestamps] == false ||
             payload[:filter_background_audio]
            raise ArgumentError, 'ElevenLabs file streaming requires manual commits and word timestamps'
          end
        end

        def streaming_audio_format(audio)
          return "pcm_#{audio.sample_rate}" if pcm_audio?(audio)
          return 'ulaw_8000' if [audio.channels, audio.encoding, audio.sample_rate,
                                 audio.bits_per_sample] == [1, 7, 8000, 8]

          raise ArgumentError, 'ElevenLabs streaming requires mono 16-bit PCM WAV or 8 kHz mu-law WAV audio'
        end

        def pcm_audio?(audio)
          [audio.channels, audio.encoding, audio.bits_per_sample] == [1, 1, 16] &&
            SAMPLE_RATES.include?(audio.sample_rate)
        end

        def streaming_transcription_url(payload, audio_format:)
          language_detection = payload.fetch(:include_language_detection, true)
          params = payload.except(:file).merge(audio_format:, commit_strategy: 'manual', include_timestamps: true,
                                               include_language_detection: language_detection)
          uri = URI.join("#{@provider.api_base.sub(%r{/+\z}, '')}/",
                         "v1/speech-to-text/realtime?#{URI.encode_www_form(params)}")
          uri.scheme = uri.scheme == 'https' ? 'wss' : 'ws'
          uri.to_s
        end

        def transcription_segment_bytes(audio)
          audio.sample_rate * audio.channels * audio.bits_per_sample / 8 * 20
        end

        def send_transcription_audio(socket, audio, commits)
          offset = 0
          segment_bytes = transcription_segment_bytes(audio)
          while offset < audio.data.bytesize
            length = [16_384, segment_bytes - (offset % segment_bytes)].min
            data = audio.data.byteslice(offset, length)
            offset += data.bytesize
            commit = (offset % segment_bytes).zero? || offset == audio.data.bytesize
            socket.send_text(JSON.generate(message_type: 'input_audio_chunk',
                                           'audio_base_64' => Base64.strict_encode64(data),
                                           sample_rate: audio.sample_rate, commit:))
            commits.pop if commit
          end
        end

        def process_transcription_event(event, prefix: false)
          case event['message_type']
          when 'partial_transcript'
            yield TranscriptionChunk.new(type: TranscriptionChunk::PARTIAL, text: event['text'], raw: event)
          when 'committed_transcript'
            text = event['text']
            yield TranscriptionChunk.new(type: TranscriptionChunk::DELTA, delta: prefix ? " #{text}" : text, raw: event)
          when 'committed_transcript_with_timestamps'
            return event
          else
            raise Error, event['error'] if event['error']
          end
          nil
        end
      end
    end
  end
end
