# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Streaming methods of the OpenAI API integration
      module Streaming
        module_function

        def stream_url
          completion_url
        end

        def build_chunk(data)
          Chunk.new(
            role: :assistant,
            model_id: data['model'],
            content: data.dig('choices', 0, 'delta', 'content'),
            tool_calls: parse_tool_calls(data.dig('choices', 0, 'delta', 'tool_calls'), parse_arguments: false),
            input_tokens: data.dig('usage', 'prompt_tokens'),
            output_tokens: data.dig('usage', 'completion_tokens')
          )
        end
      end
    end
  end
end
