# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Streaming methods for the Ollama API implementation
      module Streaming
        # Need to make stream_completion public for chat.rb to access
        def stream_completion(model, payload, &block) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          url = "api/chat"
          accumulator = StreamAccumulator.new

          post(url, payload) do |req|
            req.options.on_data = stream_handler(accumulator, &block)
          end

          message = accumulator.to_message

          accumulator.to_message
        end

        private

        # Handle streaming
        def stream_handler(accumulator, &block) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          to_json_stream do |data| # rubocop:disable Metrics/BlockLength
            chunk = Chunk.new(
              role: :assistant,
              content: data.dig('message', 'content'),
              model_id: data['model'],

              # NOTE: unavailable in the response - https://ollama.readthedocs.io/en/api/#streaming-responses
              input_tokens: nil,
              output_tokens: nil,
            )

            accumulator.add(chunk)
            block.call(chunk)
          end
        end
      end
    end
  end
end
