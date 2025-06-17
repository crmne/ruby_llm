# frozen_string_literal: true

module RubyLLM
  module Providers
    module Dify
      # Streaming methods of the OpenAI API integration
      module Streaming
        module_function

        def stream_url
          completion_url
        end

        def build_chunk(data)
          Chunk.new(
            role: :assistant,
            conversation_id: data['conversation_id'],
            model_id: nil,
            content: data['answer'],
            tool_calls: nil,
            input_tokens: data.dig('metadata', 'usage', 'prompt_tokens'),
            output_tokens: data.dig('metadata', 'usage', 'completion_tokens')
          )
        end
      end
    end
  end
end
