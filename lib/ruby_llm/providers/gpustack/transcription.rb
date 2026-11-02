# frozen_string_literal: true

module RubyLLM
  module Providers
    class GPUStack
      # GPUStack's vLLM transcription stream uses Chat Completions deltas.
      module Transcription
        module_function

        # Usage may follow the finish reason in an event of its own, so only
        # the end of the stream can say the transcript is done.
        def stream_transcription(payload, model:, &block)
          last = nil
          result = super({ stream_include_usage: 'true' }.merge(payload), model:) do |chunk|
            last = chunk
            block.call(chunk) unless chunk.done?
          end
          block.call(RubyLLM::TranscriptionChunk.new(type: RubyLLM::TranscriptionChunk::DONE, text: result.text,
                                                     raw: last&.raw))
          result
        end

        def build_transcription_chunk(data)
          return super unless data.key?('choices')

          choice = data['choices'].first

          RubyLLM::TranscriptionChunk.new(
            type: choice ? RubyLLM::TranscriptionChunk::DELTA : RubyLLM::TranscriptionChunk::DONE,
            delta: choice&.dig('delta', 'content'),
            raw: data
          )
        end
      end
    end
  end
end
