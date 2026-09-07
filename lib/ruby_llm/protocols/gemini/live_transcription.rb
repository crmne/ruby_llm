# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      class LiveTranscription < Protocol # :nodoc: all
        def transcribe(audio_file, model:, language:, format: nil, speaker_names: nil,
                       speaker_references: nil, provider_options: {}, prompt: nil, temperature: nil, &block)
          validate_transcription_request(format:, speaker_names:, speaker_references:, temperature:)
          audio = transcription_audio(audio_file)
          setup = render_transcription_setup(model:, language:, prompt:, provider_options:)

          track_usage(:transcription) do
            @usage_tracker.start
            events = collect_transcription(audio, setup, &block)
            result = parse_transcription_events(events, audio:, model:)
            block&.call(TranscriptionChunk.new(type: TranscriptionChunk::DONE, text: result.text, raw: events.last))
            result
          end
        end

        def validate_transcription_request(format:, speaker_names:, speaker_references:, temperature:)
          return unless format || speaker_names || speaker_references || temperature

          raise ArgumentError, 'Google Live transcription does not accept format, diarization, or temperature'
        end

        def transcription_audio(file)
          attachments = Attachment.wrap(file, config: @config)
          raise ArgumentError, 'Transcription requires exactly one audio file' unless attachments.one?

          audio = RubyLLM::Transcription::WavAudio.new(attachments.first.content)
          unless [audio.encoding, audio.channels, audio.bits_per_sample] == [1, 1, 16] &&
                 audio.data.bytesize.positive? && audio.data.bytesize.even?
            raise ArgumentError, 'Google Live transcription requires non-empty mono 16-bit PCM WAV audio'
          end

          audio
        end

        def render_transcription_setup(model:, language:, prompt:, provider_options:)
          payload = { model: transcription_model_name(model), generationConfig: { responseModalities: ['TEXT'] },
                      inputAudioTranscription: { languageCodes: language && Array(language),
                                                 customVocabulary: prompt && Array(prompt) }.compact,
                      realtimeInputConfig: { automaticActivityDetection: { disabled: true } } }
          payload = Support::Utils.deep_merge(payload, provider_options)
          validate_transcription_setup(payload)
          { setup: payload }
        end

        def validate_transcription_setup(payload)
          config = payload.fetch(:inputAudioTranscription)
          if config[:diarization] || config[:wordTimestamp]
            raise ArgumentError, 'Google Live transcription does not support diarization or word timestamps'
          end
          return if payload.dig(:realtimeInputConfig, :automaticActivityDetection, :disabled) == true

          raise ArgumentError, 'Google file transcription requires manual activity boundaries'
        end

        def transcription_model_name(model)
          "models/#{model}"
        end

        def websocket_service
          'google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent'
        end

        def transcription_websocket_url
          uri = URI.parse(@provider.api_base)
          uri.scheme = uri.scheme == 'https' ? 'wss' : 'ws'
          uri.path = "/ws/#{websocket_service}"
          uri.to_s
        end

        def collect_transcription(audio, setup, &block)
          events = []
          ready = Queue.new
          Transport::WebsocketConnection.open(
            transcription_websocket_url, headers: @provider.headers.transform_keys(&:to_s), config: @config
          ) do |socket|
            socket.send_text(JSON.generate(setup))
            write = lambda { |connection|
              ready.pop
              send_transcription_audio(connection, audio)
            }
            socket.each_message(write:) do |message|
              event = JSON.parse(message)
              events << event
              ready << true if event.key?('setupComplete')
              process_transcription_event(event, &block)
              socket.close if event.dig('serverContent', 'generationComplete')
            end
          end
          unless events.last&.dig('serverContent', 'generationComplete')
            raise Error, 'Google Live transcription ended before generation completed'
          end

          events
        end

        def send_transcription_audio(socket, audio)
          socket.send_text(JSON.generate(realtimeInput: { activityStart: {} }))
          bytes = [audio.sample_rate / 10, 1].max * 2
          offset = 0
          while offset < audio.data.bytesize
            chunk = audio.data.byteslice(offset, bytes)
            input = { audio: { mimeType: "audio/pcm;rate=#{audio.sample_rate}", data: Base64.strict_encode64(chunk) } }
            socket.send_text(JSON.generate(realtimeInput: input))
            offset += chunk.bytesize
          end
          socket.send_text(JSON.generate(realtimeInput: { activityEnd: {} }))
        end

        def process_transcription_event(event)
          raise Error, event.dig('error', 'message') || 'Google Live transcription failed' if event['error']
          return unless block_given?

          content = event['serverContent'] || {}
          if content['interimInputTranscription']
            yield TranscriptionChunk.new(type: TranscriptionChunk::PARTIAL,
                                         text: content.dig('interimInputTranscription', 'text'), raw: event)
          elsif content['inputTranscription']
            yield TranscriptionChunk.new(type: TranscriptionChunk::DELTA,
                                         delta: content.dig('inputTranscription', 'text'), raw: event)
          end
        end

        def parse_transcription_events(events, audio:, model:)
          text = events.filter_map { |event| event.dig('serverContent', 'inputTranscription', 'text') }.join
          usage = events.reverse.find { |event| event['usageMetadata'] }&.fetch('usageMetadata') || {}
          RubyLLM::Transcription.new(
            text:, model:, duration: audio.duration,
            input_tokens: usage['promptTokenCount'], output_tokens: usage['candidatesTokenCount']
          )
        end
      end
    end
  end
end
