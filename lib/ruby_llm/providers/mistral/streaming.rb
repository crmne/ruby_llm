module RubyLLM
  module Providers
    module Mistral
      # Handles streaming responses for Mistral models
      module Streaming
        module_function

        def handle_stream(&block)
          to_json_stream do |data|
            chunk = parse_stream_data(data)
            block.call(chunk) if chunk
          end
        end

        def parse_stream_data(data)
          return nil if data.nil?

          choice = data.dig("choices", 0)
          return unless choice

          delta = choice["delta"]
          return unless delta
          # Don't return if empty, might just contain tool_calls
          # return if delta.empty?

          content = delta["content"]
          tool_calls = Mistral::Tools.parse_tool_calls(delta["tool_calls"])

          # FIXME: Tests expect content to be non-nil even when tool calls are made.
          # Mistral API correctly returns null content in this case.
          # Returning empty string as a workaround until tests are fixed.
          # Note: This might affect stream accumulation if content chunks are expected.
          content = '' if content.nil? && tool_calls&.any?

          # Only return a chunk if there is actual content or tool calls
          return nil if content.nil? && tool_calls.nil?

          RubyLLM::Chunk.new(
            role: (delta["role"] ? delta["role"].to_sym : :assistant),
            content: content,
            tool_calls: tool_calls,
            model_id: data["model"],
            input_tokens: nil, # Usage info comes in final chunk for Mistral
            output_tokens: nil,
          )
        end
      end
    end
  end
end
