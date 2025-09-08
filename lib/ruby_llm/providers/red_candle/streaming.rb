# frozen_string_literal: true

module RubyLLM
  module Providers
    class RedCandle
      module Streaming
        def stream(payload, &block)
          if payload[:stream]
            perform_streaming_completion!(payload, &block)
          else
            # Non-streaming fallback
            result = perform_completion!(payload)
            # Yield the complete result as a single chunk
            chunk = {
              content: result[:content],
              role: result[:role],
              finish_reason: result[:finish_reason]
            }
            block.call(chunk)
          end
        end

        private

        def stream_processor
          # Red Candle handles streaming internally through blocks
          # This method is here for compatibility with the base streaming interface
          nil
        end

        def process_stream_response(response)
          # Red Candle doesn't use HTTP responses
          # Streaming is handled directly in perform_streaming_completion!
          response
        end
      end
    end
  end
end