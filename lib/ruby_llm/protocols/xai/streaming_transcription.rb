# frozen_string_literal: true

module RubyLLM
  module Protocols
    module XAI
      module StreamingTranscription # :nodoc: all
        SAMPLE_RATES = [8000, 16_000, 22_050, 24_000, 44_100, 48_000].freeze
        ENCODINGS = { [1, 16] => 'pcm', [6, 8] => 'alaw', [7, 8] => 'mulaw' }.freeze

        def stream_transcription(payload, model:, &block)
          audio = RubyLLM::Transcription::WavAudio.new(payload.fetch(:file).io.read)
          url = streaming_transcription_url(payload, audio:)
          segments = []
          completed = []
          @usage_tracker.start
          Transport::WebsocketConnection.open(url, headers: @provider.headers, config: @config) do |socket|
            receive_streamed_transcription(socket, audio, segments, completed, &block)
          end
          raise Error, 'xAI transcription ended before its final transcript' unless completed.size == audio.channels

          result = build_streamed_transcription(segments, completed, model:, language: payload[:language])
          block.call(TranscriptionChunk.new(type: TranscriptionChunk::DONE, text: result.text, raw: completed.last))
          result
        ensure
          payload[:file]&.io&.close
        end

        def receive_streamed_transcription(socket, audio, segments, completed, &block)
          ready = Queue.new
          write = lambda do |connection|
            ready.pop
            send_transcription_audio(connection, audio)
          end
          socket.each_message(write:) do |message|
            process_transcription_event(JSON.parse(message), segments, completed, ready, &block)
            socket.close if completed.size == audio.channels
          end
        end

        def process_transcription_event(event, segments, completed, ready, &)
          case event['type']
          when 'transcript.created'
            ready << true
          when 'transcript.partial'
            process_transcription_segment(event, segments, &)
          when 'transcript.done'
            process_transcription_segment(event, segments, &)
            completed << event unless completed.any? { |item| item['channel_index'] == event['channel_index'] }
          when 'error'
            raise Error, event['message'] || 'xAI transcription failed'
          end
        end

        def streaming_transcription_url(payload, audio:)
          encoding = ENCODINGS[[audio.encoding, audio.bits_per_sample]]
          unless encoding && SAMPLE_RATES.include?(audio.sample_rate) && (1..8).cover?(audio.channels)
            raise ArgumentError, 'xAI streaming requires 16-bit PCM or 8-bit G.711 WAV audio at a supported sample rate'
          end

          params = payload.except(:file).merge(encoding:, sample_rate: audio.sample_rate, interim_results: true)
          params[:channels] = audio.channels
          params[:multichannel] = audio.channels > 1
          pairs = params.flat_map { |key, value| Array(value).map { |item| [key, item] } }
          uri = URI.join("#{@provider.api_base.sub(%r{/+\z}, '')}/", "stt?#{URI.encode_www_form(pairs)}")
          uri.scheme = uri.scheme == 'https' ? 'wss' : 'ws'
          uri.to_s
        end

        def send_transcription_audio(socket, audio)
          offset = 0
          bytes = audio.sample_rate * audio.channels * audio.bits_per_sample / 8 / 10
          while offset < audio.data.bytesize
            socket.send_binary(audio.data.byteslice(offset, bytes))
            offset += bytes
            sleep 0.1
          end
          socket.send_text(JSON.generate(type: 'audio.done'))
        end

        def process_transcription_segment(event, segments)
          text = event['text'].to_s
          return if text.empty?

          unless event['is_final'] || event['type'] == 'transcript.done'
            yield TranscriptionChunk.new(type: TranscriptionChunk::PARTIAL, text:, raw: event)
            return
          end

          segment = parse_transcription_segment(event)
          return if segments.any? { |previous| duplicate_transcription_segment?(previous, segment) }

          delta = segments.empty? ? text : " #{text}"
          segments << segment
          yield TranscriptionChunk.new(type: TranscriptionChunk::SEGMENT, delta:, segment:, raw: event)
        end

        def parse_transcription_segment(event)
          { 'text' => event['text'], 'start' => event['start'],
            'end' => event['start'] && (event['start'] + event['duration'].to_f),
            'channel' => event['channel_index'], 'words' => event['words'], 'language' => event['language'] }.compact
        end

        def duplicate_transcription_segment?(previous, segment)
          same_text = previous.values_at('text', 'channel', 'words') == segment.values_at('text', 'channel', 'words')
          same_time = previous.values_at('start', 'end') == segment.values_at('start', 'end')
          same_text && (segment['start'].nil? || same_time)
        end

        def build_streamed_transcription(segments, completed, model:, language:)
          RubyLLM::Transcription.new(
            text: segments.map { |segment| segment.fetch('text') }.join(' '), model:,
            language: language || segments.filter_map { |segment| segment['language'] }.last,
            duration: completed.filter_map { |event| event['duration'] }.max,
            segments:, words: segments.flat_map { |segment| segment['words'] || [] }
          )
        end
      end
    end
  end
end
