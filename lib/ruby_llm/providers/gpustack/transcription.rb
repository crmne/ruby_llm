# frozen_string_literal: true

module RubyLLM
  module Providers
    class GPUStack
      # GPUStack's vLLM transcription stream uses Chat Completions deltas.
      module Transcription
        module_function

        def stream_transcription(payload, model:, &)
          super({ stream_include_usage: 'true' }.merge(payload), model:, &)
        end

        def build_transcription_chunk(data)
          return super unless data.key?('choices')

          choice = data['choices'].first || {}
          finished = choice['finish_reason'] || data['choices'].empty?

          RubyLLM::TranscriptionChunk.new(
            type: finished ? RubyLLM::TranscriptionChunk::DONE : RubyLLM::TranscriptionChunk::DELTA,
            delta: choice.dig('delta', 'content'),
            raw: data
          )
        end
      end
    end
  end
end
