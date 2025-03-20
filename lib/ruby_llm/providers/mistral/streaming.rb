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
          choice = data.dig("choices", 0)
          return unless choice

          delta = choice["delta"]
          return unless delta
          return if delta.empty?

          content = delta["content"]
          tool_calls = parse_tool_calls(delta["tool_calls"])

          RubyLLM::Chunk.new(
            role: (delta["role"] ? delta["role"].to_sym : :assistant),
            content: content,
            tool_calls: tool_calls,
            model_id: data["model"],
            input_tokens: nil,
            output_tokens: nil,
          )
        end

        def parse_tool_calls(tool_calls)
          return nil unless tool_calls&.any?

          tool_calls.to_h do |tc|
            [
              tc["id"],
              RubyLLM::ToolCall.new(
                id: tc["id"],
                name: tc.dig("function", "name"),
                arguments: parse_tool_arguments(tc.dig("function", "arguments")),
              ),
            ]
          end
        end

        def parse_tool_arguments(args)
          return args unless args.is_a?(String)

          # Try to parse the arguments string as JSON
          begin
            JSON.parse(args)
          rescue JSON::ParserError
            # If parsing fails, return the original string
            args
          end
        end
      end
    end
  end
end
