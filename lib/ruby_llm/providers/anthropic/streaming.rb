# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Streaming methods of the Anthropic API integration
      module Streaming
        private

        def stream_url
          completion_url
        end

        def build_chunk(data)
          delta_type = data.dig('delta', 'type')

          Chunk.new(
            role: :assistant,
            model_id: extract_model_id(data),
            content: extract_content_delta(data, delta_type),
            thinking: Thinking.build(
              text: extract_thinking_delta(data, delta_type),
              signature: extract_signature_delta(data, delta_type)
            ),
            input_tokens: extract_input_tokens(data),
            output_tokens: extract_output_tokens(data),
            cached_tokens: extract_cached_tokens(data),
            cache_creation_tokens: extract_cache_creation_tokens(data),
            tool_calls: extract_tool_calls(data)
          )
        end

        def extract_content_delta(data, delta_type)
          return data.dig('delta', 'text') if delta_type == 'text_delta'

          nil
        end

        def extract_thinking_delta(data, delta_type)
          return data.dig('delta', 'thinking') if delta_type == 'thinking_delta'

          nil
        end

        def extract_signature_delta(data, delta_type)
          return data.dig('delta', 'signature') if delta_type == 'signature_delta'

          nil
        end

        def json_delta?(data)
          data['type'] == 'content_block_delta' && data.dig('delta', 'type') == 'input_json_delta'
        end

        def parse_streaming_error(data)
          error_data = JSON.parse(data)
          return unless error_data['type'] == 'error'

          case error_data.dig('error', 'type')
          when 'overloaded_error'
            [529, error_data['error']['message']]
          else
            [500, error_data['error']['message']]
          end
        end
      end
    end
  end
end
