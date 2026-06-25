# frozen_string_literal: true

module RubyLLM
  module Providers
    class LLMGateway
      # Streaming methods of the LLMGateway API integration
      module Streaming
        module_function

        def build_chunk(data)
          usage = data['usage'] || {}
          delta = data.dig('choices', 0, 'delta') || {}

          Chunk.new(
            role: :assistant,
            model_id: data['model'],
            content: delta['content'],
            thinking: Thinking.build(
              text: extract_thinking_text(delta),
              signature: extract_thinking_signature(delta)
            ),
            tool_calls: parse_tool_calls(delta['tool_calls'], parse_arguments: false),
            input_tokens: input_tokens(usage),
            output_tokens: output_tokens(usage),
            cached_tokens: cache_read_tokens(usage),
            cache_creation_tokens: cache_write_tokens(usage),
            thinking_tokens: thinking_tokens(usage),
            finish_reason: data.dig('choices', 0, 'finish_reason')
          )
        end
      end
    end
  end
end
