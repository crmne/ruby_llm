# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Streaming
        # Module for handling content extraction from AWS Bedrock streaming responses.
        module ContentExtraction
          def json_delta?(data)
            data['type'] == 'content_block_delta' && data.dig('delta', 'type') == 'input_json_delta'
          end

          def extract_streaming_content(data)
            return '' unless data.is_a?(Hash)

            extract_content_by_type(data)
          end

          def extract_thinking_delta(data)
            return nil unless data.is_a?(Hash)

            if data['type'] == 'content_block_delta' && data.dig('delta', 'type') == 'thinking_delta'
              return data.dig('delta', 'thinking')
            end

            if data['type'] == 'content_block_start' && data.dig('content_block', 'type') == 'thinking'
              return data.dig('content_block', 'thinking') || data.dig('content_block', 'text')
            end

            nil
          end

          def extract_signature_delta(data)
            return nil unless data.is_a?(Hash)

            signature = extract_signature_from_delta(data)
            return signature if signature

            return nil unless data['type'] == 'content_block_start'

            extract_signature_from_block(data['content_block'])
          end

          def extract_tool_calls(data)
            data.dig('message', 'tool_calls') || data['tool_calls']
          end

          def extract_model_id(data)
            data.dig('message', 'model') || @model_id
          end

          def extract_input_tokens(data)
            data.dig('message', 'usage', 'input_tokens')
          end

          def extract_output_tokens(data)
            data.dig('message', 'usage', 'output_tokens') || data.dig('usage', 'output_tokens')
          end

          def extract_cached_tokens(data)
            data.dig('message', 'usage', 'cache_read_input_tokens') || data.dig('usage', 'cache_read_input_tokens')
          end

          def extract_cache_creation_tokens(data)
            direct = data.dig('message', 'usage',
                              'cache_creation_input_tokens') || data.dig('usage', 'cache_creation_input_tokens')
            return direct if direct

            breakdown = data.dig('message', 'usage', 'cache_creation') || data.dig('usage', 'cache_creation')
            return unless breakdown.is_a?(Hash)

            breakdown.values.compact.sum
          end

          def extract_thinking_tokens(data)
            data.dig('message', 'usage', 'thinking_tokens') ||
              data.dig('message', 'usage', 'output_tokens_details', 'thinking_tokens') ||
              data.dig('usage', 'thinking_tokens') ||
              data.dig('usage', 'output_tokens_details', 'thinking_tokens') ||
              data.dig('message', 'usage', 'reasoning_tokens') ||
              data.dig('message', 'usage', 'output_tokens_details', 'reasoning_tokens') ||
              data.dig('usage', 'reasoning_tokens') ||
              data.dig('usage', 'output_tokens_details', 'reasoning_tokens')
          end

          private

          def extract_content_by_type(data)
            case data['type']
            when 'content_block_start' then extract_block_start_content(data)
            when 'content_block_delta' then extract_delta_content(data)
            else ''
            end
          end

          def extract_block_start_content(data)
            content_block = data['content_block'] || {}
            return '' if %w[thinking redacted_thinking].include?(content_block['type'])

            content_block['text'].to_s
          end

          def extract_delta_content(data)
            delta = data['delta'] || {}
            return '' if %w[thinking_delta signature_delta].include?(delta['type'])

            delta['text'].to_s
          end

          def extract_signature_from_delta(data)
            return unless data['type'] == 'content_block_delta'
            return unless data.dig('delta', 'type') == 'signature_delta'

            data.dig('delta', 'signature')
          end

          def extract_signature_from_block(content_block)
            block = content_block || {}
            return block['signature'] if block['type'] == 'thinking' && block['signature']
            return block['data'] if block['type'] == 'redacted_thinking'

            nil
          end
        end
      end
    end
  end
end
