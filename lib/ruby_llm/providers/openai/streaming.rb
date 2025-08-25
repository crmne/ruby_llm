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

        def responses_stream_url
          responses_url
        end

        def build_chunk(data)
          # Check if this is responses API format vs chat completions format
          if data['type'] # Responses API has a 'type' field
            build_responses_chunk(data)
          else
            build_chat_completions_chunk(data)
          end
        end

        def build_responses_chunk(data)
          case data['type']
          when 'response.text.delta'
            # Text content delta - deprecated format
            Chunk.new(
              role: :assistant,
              model_id: data.dig('response', 'model'),
              content: data['delta'],
              tool_calls: nil,
              input_tokens: nil,
              output_tokens: nil
            )
          when 'response.output_text.delta'
            # Text content delta - new format
            Chunk.new(
              role: :assistant,
              model_id: nil, # Model is in the completion event
              content: data['delta'],
              tool_calls: nil,
              input_tokens: nil,
              output_tokens: nil
            )
          when 'response.function_call_arguments.delta'
            # Tool call arguments delta - handled by accumulator
            # We need to track these deltas to build up the complete tool call
            build_tool_call_delta_chunk(data)
          when 'response.output_item.added'
            # New tool call or message starting
            if data.dig('item', 'type') == 'function_call'
              build_tool_call_start_chunk(data)
            else
              build_empty_chunk(data)
            end
          when 'response.output_item.done'
            # Tool call or message completed
            if data.dig('item', 'type') == 'function_call'
              build_tool_call_complete_chunk(data)
            else
              build_empty_chunk(data)
            end
          when 'response.completed'
            # Final response with usage stats
            Chunk.new(
              role: :assistant,
              model_id: data.dig('response', 'model'),
              content: nil,
              tool_calls: nil,
              input_tokens: data.dig('response', 'usage', 'input_tokens'),
              output_tokens: data.dig('response', 'usage', 'output_tokens')
            )
          else
            # Other event types (response.created, response.in_progress, etc.)
            build_empty_chunk(data)
          end
        end

        def build_chat_completions_chunk(data)
          Chunk.new(
            role: :assistant,
            model_id: data['model'],
            content: data.dig('choices', 0, 'delta', 'content'),
            tool_calls: parse_tool_calls(data.dig('choices', 0, 'delta', 'tool_calls'), parse_arguments: false),
            input_tokens: data.dig('usage', 'prompt_tokens'),
            output_tokens: data.dig('usage', 'completion_tokens')
          )
        end

        def build_tool_call_delta_chunk(data)
          # For tool call argument deltas, we need to create a partial tool call
          # The accumulator will handle building up the complete arguments
          tool_call_data = {
            'id' => data['item_id'],
            'function' => {
              'name' => '', # Name comes from the initial item.added event
              'arguments' => data['delta'] || ''
            }
          }

          Chunk.new(
            role: :assistant,
            model_id: nil,
            content: nil,
            tool_calls: { data['item_id'] => create_streaming_tool_call(tool_call_data) },
            input_tokens: nil,
            output_tokens: nil
          )
        end

        def build_tool_call_start_chunk(data)
          item = data['item']
          tool_call_data = {
            'id' => item['id'],
            'function' => {
              'name' => item['name'],
              'arguments' => item['arguments'] || ''
            }
          }

          Chunk.new(
            role: :assistant,
            model_id: nil,
            content: nil,
            tool_calls: { item['id'] => create_streaming_tool_call(tool_call_data) },
            input_tokens: nil,
            output_tokens: nil
          )
        end

        def build_tool_call_complete_chunk(data)
          item = data['item']
          tool_call_data = {
            'id' => item['id'],
            'function' => {
              'name' => item['name'],
              'arguments' => item['arguments'] || ''
            }
          }

          Chunk.new(
            role: :assistant,
            model_id: nil,
            content: nil,
            tool_calls: { item['id'] => create_streaming_tool_call(tool_call_data) },
            input_tokens: nil,
            output_tokens: nil
          )
        end

        def build_empty_chunk(data)
          Chunk.new(
            role: :assistant,
            model_id: data.dig('response', 'model'),
            content: nil,
            tool_calls: nil,
            input_tokens: nil,
            output_tokens: nil
          )
        end

        def create_streaming_tool_call(tool_call_data)
          ToolCall.new(
            id: tool_call_data['id'],
            name: tool_call_data.dig('function', 'name'),
            arguments: tool_call_data.dig('function', 'arguments')
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
