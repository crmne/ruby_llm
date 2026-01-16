# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Streaming methods of the OpenAI API integration
      module Streaming
        module_function

        def stream_url
          completion_url
        end

        def build_chunk(data)
          usage = data['usage'] || {}
          cached_tokens = usage.dig('prompt_tokens_details', 'cached_tokens')
          delta = data.dig('choices', 0, 'delta') || {}
          content_source = delta['content'] || data.dig('choices', 0, 'message', 'content')
          content, thinking_from_blocks = OpenAI::Chat.extract_content_and_thinking(content_source)

          Chunk.new(
            role: :assistant,
            model_id: data['model'],
            content: content,
            thinking: Thinking.build(
              text: thinking_from_blocks || delta['reasoning_content'] || delta['reasoning'],
              signature: delta['reasoning_signature']
            ),
            tool_calls: parse_tool_calls(delta['tool_calls'], parse_arguments: false),
            input_tokens: usage['prompt_tokens'],
            output_tokens: usage['completion_tokens'],
            cached_tokens: cached_tokens,
            cache_creation_tokens: 0,
            thinking_tokens: usage.dig('completion_tokens_details', 'reasoning_tokens')
          )
        end

        def parse_streaming_error(data)
          error_data = JSON.parse(data)
          return unless error_data['error']

          case error_data.dig('error', 'type')
          when 'server_error'
            [500, error_data['error']['message']]
          when 'rate_limit_exceeded', 'insufficient_quota'
            [429, error_data['error']['message']]
          else
            [400, error_data['error']['message']]
          end
        end
      end
    end
  end
end
