# frozen_string_literal: true

require 'json'

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
          delta = data.dig('choices', 0, 'delta') || {}
          content_source = delta['content'] || data.dig('choices', 0, 'message', 'content')
          content, thinking_from_blocks = extract_content_and_thinking(content_source)

          Chunk.new(
            role: :assistant,
            model_id: data['model'],
            content: content,
            citations: extract_chunk_citations(delta, data),
            thinking: Thinking.build(
              text: thinking_from_blocks || delta['reasoning_content'] || delta['reasoning'],
              signature: delta['reasoning_signature']
            ),
            tool_calls: parse_tool_calls(delta['tool_calls'], parse_arguments: false),
            input_tokens: input_tokens(usage),
            output_tokens: output_tokens(usage),
            cached_tokens: cache_read_tokens(usage),
            cache_creation_tokens: cache_write_tokens(usage),
            thinking_tokens: thinking_tokens(usage)
          )
        end

        def extract_chunk_citations(delta, data)
          annotations = parse_annotations(delta['annotations'], nil)
          return annotations if annotations.any?

          parse_root_citations(data)
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
