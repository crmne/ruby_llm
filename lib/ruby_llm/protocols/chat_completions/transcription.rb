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

        def render_transcription_payload(file_part, model:, language:, format: nil, speaker_names: nil,
                                         speaker_references: nil, provider_options: {}, prompt: nil,
                                         temperature: nil)
          {
            model: model,
            file: file_part,
            language: language,
            chunking_strategy: default_chunking_strategy(model),
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

        def default_chunking_strategy(model)
          'auto' if model.include?('diarize')
        end

        def reported_cost(_usage)
          nil
        end

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
          segments = chunks.filter_map(&:segment)

          RubyLLM::Transcription.new(
            text: final&.text || streamed_transcript_text(chunks),
            model: model,
            language: data['language'],
            duration: usage['seconds'],
            segments: segments.empty? ? nil : segments,
            input_tokens: usage['input_tokens'],
            output_tokens: usage['output_tokens'],
            reported_cost: reported_cost(usage)
          )
        end

        # Diarization models stream segments instead of deltas, so the
        # transcript is rebuilt from whichever the provider sent.
        def streamed_transcript_text(chunks)
          deltas = chunks.filter_map(&:delta)
          return deltas.join if deltas.any?

          chunks.filter_map { |chunk| chunk.segment&.fetch('text', nil) }.join(' ')
        end

        def parse_transcription_response(response, model:)
          data = response.body

          return RubyLLM::Transcription.new(text: data, model: model) if data.is_a?(String)

          usage = data['usage'] || {}

          RubyLLM::Transcription.new(
            text: data['text'],
            model: model,
            language: data['language'],
            duration: data['duration'] || usage['seconds'],
            segments: data['segments'],
            words: data['words'],
            input_tokens: usage['input_tokens'] || usage['prompt_tokens'],
            output_tokens: usage['output_tokens'] || usage['completion_tokens'],
            reported_cost: reported_cost(usage)
          )
        end
      end
    end
  end
end
