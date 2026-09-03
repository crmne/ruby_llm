# frozen_string_literal: true

require 'json'

module RubyLLM
  module Protocols
    class ChatCompletions
      # Streaming methods of the OpenAI API integration
      module Streaming
        module_function

        def stream_url
          completion_url
        end

        def build_chunk(data)
          usage = data['usage'] || {}
          delta = data.dig('choices', 0, 'delta') || {}
          content_source = delta['content'] || data.dig('choices', 0, 'message', 'content')
          content, thinking_from_blocks = extract_content_and_thinking(content_source)

          Chunk.new(
            role: :assistant,
            model: data['model'],
            content: content,
            citations: extract_chunk_citations(delta, data),
            thinking: Thinking.build(
              text: thinking_from_blocks || delta['reasoning_content'] || delta['reasoning'],
              signature: delta['reasoning_signature']
            ),
            tool_calls: parse_tool_calls(delta['tool_calls'], parse_arguments: false, stream_keys: true),
            input_tokens: input_tokens(usage),
            output_tokens: output_tokens(usage),
            cache_read_tokens: cache_read_tokens(usage),
            cache_write_tokens: cache_write_tokens(usage),
            thinking_tokens: thinking_tokens(usage),
            server_tool_use: server_tool_use(usage),
            reported_cost: reported_cost(usage),
            finish_reason: normalize_finish_reason(data.dig('choices', 0, 'finish_reason'))
          )
        end

        def extract_chunk_citations(delta, data)
          annotations = parse_annotations(delta['annotations'], nil)
          return annotations if annotations.any?

          parse_root_citations(data)
        end

        def parse_streaming_error(data)
          error_data = JSON.parse(data)
          return [nil, error_data.to_s] unless error_data.is_a?(Hash)

          error = error_data['error']
          return [nil, error.to_s] unless error.is_a?(Hash)

          case error['type']
          when 'server_error'
            [500, error['message']]
          when 'rate_limit_exceeded', 'insufficient_quota'
            [429, error['message']]
          else
            [400, error['message']]
          end
        end
      end
    end
  end
end
