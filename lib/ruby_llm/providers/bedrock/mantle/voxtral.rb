# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Mantle
        # Voxtral transcription through Mantle's audio-capable Chat Completions API.
        class Voxtral < ChatCompletions
          def transcribe(audio_file, model:, language:, format: nil, speaker_names: nil,
                         speaker_references: nil, provider_options: {}, prompt: nil, temperature: nil, &block)
            validate_transcription_options(format:, speaker_names:, speaker_references:)

            track_usage(:transcription) do
              payload = render_transcription_payload(audio_file, model:, language:, prompt:, temperature:,
                                                                 provider_options:)
              next stream_transcription(payload, model:, &block) if block

              parse_transcription_response(signed_post(completion_url, payload), model:)
            end
          end

          def render_transcription_options(timestamps:, **)
            return {} if timestamps.nil?

            raise ArgumentError, 'Bedrock Voxtral does not return timestamps'
          end

          private

          def stream_transcription(payload, model:)
            payload = Support::Utils.deep_merge(payload, stream: true, stream_options: { include_usage: true })
            message = stream_response(payload) do |chunk|
              @usage_tracker.observe(chunk) if chunk.tokens.input || chunk.tokens.output
              next if chunk.content.to_s.empty?

              yield RubyLLM::TranscriptionChunk.new(type: RubyLLM::TranscriptionChunk::DELTA, delta: chunk.content)
            end
            unless message.finish_reason == :stop
              raise Error.new('Bedrock Voxtral did not complete the transcript', response: message.raw)
            end

            result = RubyLLM::Transcription.new(text: message.content.to_s, model: message.model || model)
            yield RubyLLM::TranscriptionChunk.new(type: RubyLLM::TranscriptionChunk::DONE, text: result.text)
            tokens = message.tokens
            tokens = Tokens.new if tokens.input.nil? && tokens.output.nil?
            @usage_tracker.succeed_attempts(tokens: [tokens])
            result
          end

          def validate_transcription_options(format:, speaker_names:, speaker_references:)
            unless format.nil? || %w[text text/plain].include?(format)
              raise ArgumentError, 'Bedrock Voxtral returns plain text transcripts'
            end
            return unless speaker_names || speaker_references

            raise ArgumentError, 'Bedrock Voxtral does not return speaker labels or timestamps'
          end

          def render_transcription_payload(audio_file, model:, language:, prompt:, temperature:, provider_options:)
            attachments = Attachment.wrap(audio_file, config: @config)
            raise ArgumentError, 'Transcription requires exactly one audio file' unless attachments.one?

            attachment = attachments.first
            unless attachment.audio? && %w[mp3 wav].include?(attachment.format)
              raise UnsupportedAttachmentError, attachment.mime_type
            end

            content = [
              Protocols::ChatCompletions::Media.format_audio(attachment),
              { type: 'text', text: transcription_prompt(prompt, language) }
            ]
            payload = { model:, messages: [{ role: 'user', content: }], temperature: temperature || 0 }
            Support::Utils.deep_merge(payload, provider_options)
          end

          def transcription_prompt(prompt, language)
            [
              'Transcribe the audio verbatim. Return only the transcript text.',
              ("The audio language is #{language}." if language),
              prompt
            ].compact.join(' ')
          end

          def parse_transcription_response(response, model:)
            data = response.body
            text = data.dig('choices', 0, 'message', 'content')
            raise Error.new('Bedrock returned no transcript', response:) unless text.is_a?(String)

            RubyLLM::Transcription.new(text:, model: data['model'] || model,
                                       **transcription_tokens(data['usage'] || {}))
          end
        end
      end
    end
  end
end
