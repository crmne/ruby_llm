# frozen_string_literal: true

require 'json'

module RubyLLM
  module Protocols
    module Azure
      class Speech
        # Fast transcription on Azure AI Speech. The request is multipart:
        # the audio, and a JSON definition carrying the options. Several
        # languages make a candidate list Azure identifies the spoken one
        # from, a prompt becomes a phrase list, and asking for speakers
        # turns on diarization.
        module Transcription
          # Azure masks profanity unless told otherwise. Turned off so the
          # transcript reads like the transcripts every other provider
          # returns; pass <tt>provider_options: { profanityFilterMode: "Masked" }</tt>
          # to mask it.
          DEFAULT_DEFINITION = { profanityFilterMode: 'None' }.freeze

          def render_transcription_options(timestamps:, **)
            return {} if timestamps.nil? || timestamps == :word

            raise ArgumentError, 'Azure Speech transcription timestamps must be word'
          end

          def rejected_options(operation)
            operation == :transcribe ? %i[format temperature speaker_references named_speakers] : super
          end

          def transcription_url
            @provider.azure_speech_transcription_url
          end

          def render_transcription_payload(file_part, language: nil, speaker_names: nil, prompt: nil,
                                           provider_options: {}, **)
            {
              audio: file_part,
              definition: JSON.generate(render_transcription_definition(language:, speaker_names:, prompt:,
                                                                        provider_options:))
            }
          end

          def render_transcription_definition(language: nil, speaker_names: nil, prompt: nil, provider_options: {})
            definition = DEFAULT_DEFINITION.dup
            definition[:locales] = Array(language) if language
            definition[:diarization] = { enabled: true } if speaker_names
            definition[:phraseList] = { phrases: Array(prompt) } if prompt
            Support::Utils.deep_merge(definition, provider_options)
          end

          def transcribe(audio_file, model:, language:, speaker_names: nil, provider_options: {}, prompt: nil, **)
            raise_transcription_streaming_unsupported if block_given?

            track_usage(:transcription) do
              file_part = build_audio_file_part(audio_file)
              payload = render_transcription_payload(file_part, language:, speaker_names:, prompt:, provider_options:)
              response = @connection.post(transcription_url, payload, usage: @usage_tracker) do |request|
                request.headers.merge!(@provider.azure_speech_headers)
              end
              parse_transcription_response(response, model:)
            end
          end

          def parse_transcription_response(response, model:)
            data = response.body || {}
            phrases = Array(data['phrases'])
            duration = data['durationMilliseconds'] && (data['durationMilliseconds'] / 1000.0)

            RubyLLM::Transcription.new(
              text: Array(data['combinedPhrases']).map { |phrase| phrase['text'] }.join("\n"),
              model: model,
              language: phrases.filter_map { |phrase| phrase['locale'] }.first,
              duration:,
              audio_seconds: duration,
              segments: phrases.map { |phrase| timed(phrase.except('words')) },
              words: phrases.flat_map { |phrase| Array(phrase['words']).map { |word| timed(word) } }
            )
          end

          private

          def timed(part)
            offset = part['offsetMilliseconds']
            return part unless offset

            part.merge('start' => offset / 1000.0,
                       'end' => (offset + part['durationMilliseconds'].to_i) / 1000.0)
          end
        end
      end
    end
  end
end
