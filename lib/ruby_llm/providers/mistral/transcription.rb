# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Transcription dialect for the Mistral audio API. Giving speaker
      # names turns on diarization, which labels each segment with a
      # speaker id; a prompt rides along as context biasing terms.
      module Transcription
        STREAM_TYPES = {
          'transcription.text.delta' => RubyLLM::TranscriptionChunk::DELTA,
          'transcription.segment' => RubyLLM::TranscriptionChunk::SEGMENT,
          'transcription.done' => RubyLLM::TranscriptionChunk::DONE
        }.freeze

        def render_transcription_options(timestamps:, **)
          return {} if timestamps.nil?
          raise ArgumentError, 'Mistral transcription timestamps must be segment' unless timestamps == :segment

          { timestamp_granularities: ['segment'] }
        end

        module_function

        def build_transcription_chunk(data)
          type = STREAM_TYPES[data['type']]
          return super unless type

          RubyLLM::TranscriptionChunk.new(
            type: type,
            delta: (data['text'] if type == RubyLLM::TranscriptionChunk::DELTA),
            text: (data['text'] if type == RubyLLM::TranscriptionChunk::DONE),
            segment: (data.except('type') if type == RubyLLM::TranscriptionChunk::SEGMENT),
            raw: data
          )
        end

        def transcription_duration(usage)
          usage['prompt_audio_seconds'] || super
        end

        # rubocop:disable-next Lint/UnusedMethodArgument
        def render_transcription_payload(file_part, model:, language:, format: nil, speaker_names: nil,
                                         speaker_references: nil, provider_options: {}, prompt: nil,
                                         temperature: nil)
          payload = {
            model: model,
            file: file_part,
            language: language,
            temperature: temperature,
            context_bias: prompt ? Array(prompt) : nil
          }.compact
          if speaker_names
            payload[:diarize] = true
            payload[:timestamp_granularities] = ['segment']
          end
          payload.merge(provider_options)
        end
      end
    end
  end
end
