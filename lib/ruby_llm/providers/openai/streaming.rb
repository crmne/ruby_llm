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
          when 'response.output_text.delta'
            Chunk.new(
              role: :assistant,
              model_id: nil,
              content: data['delta'],
              tool_calls: nil,
              input_tokens: nil,
              output_tokens: nil
            )
          when 'response.function_call_arguments.delta'
            build_tool_call_delta_chunk(data)
          when 'response.output_item.added'
            if data.dig('item', 'type') == 'function_call'
              build_tool_call_start_chunk(data)
            else
              build_empty_chunk(data)
            end
          when 'response.output_item.done'
            if data.dig('item', 'type') == 'function_call'
              build_tool_call_complete_chunk(data)
            else
              build_empty_chunk(data)
            end
          when 'response.completed'
            Chunk.new(
              role: :assistant,
              model_id: data.dig('response', 'model'),
              content: nil,
              tool_calls: nil,
              input_tokens: data.dig('response', 'usage', 'input_tokens'),
              output_tokens: data.dig('response', 'usage', 'output_tokens')
            )
          else
            build_empty_chunk(data)
          end
        end

        def build_chat_completions_chunk(data)
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

        def build_tool_call_delta_chunk(data)
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

        def build_empty_chunk(_data)
          Chunk.new(
            role: :assistant,
            model_id: nil,
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
