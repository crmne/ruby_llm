# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Streaming methods of the Mistral API integration
      module Streaming
        module_function

        def build_chunk(data)
          Chunk.new(
            role: :assistant,
            model_id: data['model'],
            content: extract_content(data),
            tool_calls: parse_tool_calls(data.dig('choices', 0, 'delta', 'tool_calls'), parse_arguments: false),
            input_tokens: data.dig('usage', 'prompt_tokens'),
            output_tokens: data.dig('usage', 'completion_tokens')
          )
        end

        def extract_content(data)
          data = data.dig('choices', 0, 'delta', 'content')
          return '' if data.is_a?(Array) || data.is_a?(Hash)

          data.to_s
        end
      end
    end
  end
end
