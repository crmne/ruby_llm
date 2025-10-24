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

          Chunk.new(
            role: :assistant,
            model_id: data['model'],
            content: data.dig('choices', 0, 'delta', 'content'),
            tool_calls: parse_tool_calls(data.dig('choices', 0, 'delta', 'tool_calls'), parse_arguments: false),
            input_tokens: usage['prompt_tokens'],
            output_tokens: usage['completion_tokens'],
            cached_tokens: cached_tokens,
            cache_creation_tokens: 0
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
