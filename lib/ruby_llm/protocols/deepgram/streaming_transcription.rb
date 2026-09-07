# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Deepgram
      module StreamingTranscription # :nodoc: all
        def stream_live_transcription(audio_file, model:, language:, speaker_names:, provider_options:, prompt:, &block)
          attachment = Attachment.wrap(audio_file, config: @config)
          raise ArgumentError, 'Transcription requires exactly one audio file' unless attachment.one?

          track_usage(:transcription) do
            url = streaming_transcription_url(model:, language:, speaker_names:, provider_options:, prompt:)
            segments = []
            metadata = nil
            @usage_tracker.start
            Transport::WebsocketConnection.open(url, headers: @provider.headers, config: @config) do |socket|
              write = ->(connection) { send_transcription_audio(connection, attachment.first.content) }
              socket.each_message(write:) do |message|
                event = JSON.parse(message)
                case event['type']
                when 'Results'
                  process_transcription_result(event, segments, &block)
                when 'Metadata'
                  metadata = event
                when 'Error'
                  raise Error, event['description'] || event['message'] || 'Deepgram transcription failed'
                end
              end
            end
            raise Error, 'Deepgram transcription ended before its completion metadata' unless metadata

            result = build_live_transcription(segments, metadata, model:, language:)
            block.call(TranscriptionChunk.new(type: TranscriptionChunk::DONE, text: result.text, raw: metadata))
            result
          end
        end

        def streaming_transcription_url(model:, language:, speaker_names:, provider_options:, prompt:)
          params = { model:, language:, smart_format: true, interim_results: true }
          params[:diarize_model] = DIARIZE_MODEL if speaker_names
          params[:keyterm] = Array(prompt) if prompt
          params.merge!(provider_options)
          params = params.compact.flat_map { |key, value| Array(value).map { |item| [key, item] } }
          uri = URI.join("#{@provider.api_base.sub(%r{/+\z}, '')}/", "v1/listen?#{URI.encode_www_form(params)}")
          uri.scheme = uri.scheme == 'https' ? 'wss' : 'ws'
          uri.to_s
        end

        def send_transcription_audio(socket, audio)
          offset = 0
          while offset < audio.bytesize
            socket.send_binary(audio.byteslice(offset, 16_384))
            offset += 16_384
          end
          socket.send_text(JSON.generate(type: 'CloseStream'))
        end

        def process_transcription_result(event, segments)
          alternative = event.dig('channel', 'alternatives', 0) || {}
          text = alternative['transcript'].to_s
          return if text.empty?

          unless event['is_final']
            yield TranscriptionChunk.new(type: TranscriptionChunk::PARTIAL, text:, raw: event)
            return
          end

          delta = segments.empty? ? text : " #{text}"
          segment = {
            'text' => text,
            'start' => event['start'],
            'end' => event['start'].to_f + event['duration'].to_f,
            'channel' => event.dig('channel_index', 0),
            'words' => alternative['words']
          }.compact
          segments << segment
          yield TranscriptionChunk.new(type: TranscriptionChunk::SEGMENT, delta:, segment:, raw: event)
        end

        def build_live_transcription(segments, metadata, model:, language:)
          RubyLLM::Transcription.new(
            text: segments.map { |segment| segment.fetch('text') }.join(' '), model:, language:,
            duration: metadata['duration'], segments:, words: segments.flat_map { |segment| segment['words'] || [] }
          )
        end
      end
    end
  end
end
