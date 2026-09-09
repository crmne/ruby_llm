# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # Audio transcription methods for the OpenAI API integration
      module Transcription
        module_function

        def transcription_url
          'audio/transcriptions'
        end

        def render_transcription_options(timestamps:, format:, streaming:)
          return {} if timestamps.nil?

          values = Array(timestamps).map(&:to_s)
          unless values.any? && (values - %w[word segment]).empty?
            raise ArgumentError, 'Transcription timestamps must be word or segment'
          end
          if streaming || (format && format != 'verbose_json')
            raise ArgumentError, 'Transcription timestamps require a non-streaming verbose_json response'
          end

          { response_format: 'verbose_json', timestamp_granularities: values }
        end

        def render_transcription_payload(file_part, model:, language:, format: nil, speaker_names: nil,
                                         speaker_references: nil, provider_options: {}, prompt: nil,
                                         temperature: nil)
          {
            model: model,
            file: file_part,
            language: language,
            response_format: format || default_response_format(model),
            prompt: prompt,
            temperature: temperature,
            known_speaker_names: speaker_names,
            known_speaker_references: encode_speaker_references(speaker_references)
          }.compact.merge(provider_options)
        end

        def encode_speaker_references(references)
          return nil unless references

          references.map do |ref|
            Attachment.new(ref, config: @config).for_llm
          end
        end

        def reported_cost(_usage)
          nil
        end

        # Diarization models return plain text with no segments unless the
        # response format asks for them.
        def default_response_format(model)
          'diarized_json' if model.include?('diarize')
        end

        # OpenAI streams transcriptions as server-sent events carrying text
        # deltas, completed segments on diarization models, and a final
        # event with the whole transcript and its usage.
        def stream_transcription(payload, model:, &block)
          chunks = []

          stream_events(transcription_url, payload.merge(stream: 'true')) do |data|
            chunk = build_transcription_chunk(data)
            chunks << chunk
            block.call chunk
          end

          build_streamed_transcription(chunks, model: model)
        end

        def build_transcription_chunk(data)
          type = data['type']

          RubyLLM::TranscriptionChunk.new(
            type: type,
            delta: data['delta'],
            text: (data['text'] if type == RubyLLM::TranscriptionChunk::DONE),
            segment: (data.except('type') if type == RubyLLM::TranscriptionChunk::SEGMENT),
            raw: data
          )
        end

        def build_streamed_transcription(chunks, model:)
          final = chunks.reverse.find(&:done?)
          data = final&.raw || {}
          usage = data['usage'] || {}

          RubyLLM::Transcription.new(
            text: final&.text || streamed_transcript_text(chunks),
            model: model,
            language: data['language'],
            duration: transcription_duration(usage),
            segments: streamed_transcription_segments(chunks, data),
            reported_cost: reported_cost(usage),
            **transcription_tokens(usage)
          )
        end

        # Diarization models stream segments instead of deltas, so the
        # transcript is rebuilt from whichever the provider sent.
        def streamed_transcript_text(chunks)
          deltas = chunks.filter_map(&:delta)
          return deltas.join if deltas.any?

          chunks.filter_map { |chunk| chunk.segment&.fetch('text', nil) }.join(' ')
        end

        def streamed_transcription_segments(chunks, data)
          segments = data['segments'] || chunks.filter_map(&:segment)
          segments.empty? ? nil : segments
        end

        def parse_transcription_response(response, model:)
          data = response.body

          return RubyLLM::Transcription.new(text: data, model: model) if data.is_a?(String)

          usage = data['usage'] || {}

          RubyLLM::Transcription.new(
            text: data['text'],
            model: model,
            language: data['language'],
            duration: data['duration'] || transcription_duration(usage),
            segments: data['segments'],
            words: data['words'],
            reported_cost: reported_cost(usage),
            **transcription_tokens(usage)
          )
        end

        def transcription_tokens(usage)
          {
            input_tokens: usage['input_tokens'] || usage['prompt_tokens'],
            output_tokens: usage['output_tokens'] || usage['completion_tokens']
          }
        end

        def transcription_duration(usage)
          usage['seconds']
        end
      end
    end
  end
end
