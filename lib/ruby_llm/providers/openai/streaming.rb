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
          return build_responses_chunk(data) if responses_event?(data)

          build_chat_completions_chunk(data)
        end

        def build_chat_completions_chunk(data)
          usage = data['usage'] || {}
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
            input_tokens: OpenAI::Chat.input_tokens(usage),
            output_tokens: OpenAI::Chat.output_tokens(usage),
            cached_tokens: OpenAI::Chat.cache_read_tokens(usage),
            cache_creation_tokens: OpenAI::Chat.cache_write_tokens(usage),
            thinking_tokens: OpenAI::Chat.thinking_tokens(usage)
          )
        end

        def build_responses_chunk(data)
          case data['type']
          when 'response.output_text.delta'
            response_text_delta(data)
          when 'response.reasoning_summary_text.delta', 'response.reasoning_text.delta'
            response_thinking_delta(data)
          when 'response.output_item.added', 'response.output_item.done'
            response_output_item_chunk(data)
          when 'response.function_call_arguments.delta'
            response_function_call_delta(data)
          when 'response.function_call_arguments.done'
            response_function_call_done(data)
          when 'response.completed'
            response_completed_chunk(data)
          when 'response.failed'
            raise Error, response_event_error_message(data)
          else
            Chunk.new(role: :assistant, content: '')
          end
        end

        def parse_streaming_error(data)
          error_data = JSON.parse(data)
          error = error_data['error'] || error_data.dig('response', 'error')
          return unless error

          case error['type'] || error['code']
          when 'server_error'
            [500, error['message']]
          when 'rate_limit_exceeded', 'insufficient_quota'
            [429, error['message']]
          else
            [400, error['message']]
          end
        end

        def responses_event?(data)
          data['type'].to_s.start_with?('response.')
        end

        def response_text_delta(data)
          Chunk.new(
            role: :assistant,
            content: data['delta'],
            model_id: data.dig('response', 'model')
          )
        end

        def response_thinking_delta(data)
          Chunk.new(
            role: :assistant,
            content: '',
            thinking: Thinking.build(text: data['delta']),
            model_id: data.dig('response', 'model')
          )
        end

        def response_output_item_chunk(data)
          item = data['item'] || {}
          return Chunk.new(role: :assistant, content: '') unless item['type'] == 'function_call'

          response_function_call_chunk(
            stream_key: item['id'] || data['item_id'],
            call_id: item['call_id'] || data['call_id'],
            name: item['name'],
            arguments: item['arguments']
          )
        end

        def response_function_call_delta(data)
          response_function_call_chunk(
            stream_key: data['item_id'],
            call_id: nil,
            name: nil,
            arguments: data['delta']
          )
        end

        def response_function_call_done(data)
          response_function_call_chunk(
            stream_key: data['item_id'],
            call_id: data['call_id'],
            name: data['name'],
            arguments: data['arguments']
          )
        end

        def response_function_call_chunk(stream_key:, call_id:, name:, arguments:)
          key = stream_key || call_id

          Chunk.new(
            role: :assistant,
            content: nil,
            tool_calls: {
              key => ToolCall.new(id: call_id, name: name, arguments: arguments || '')
            }
          )
        end

        def response_completed_chunk(data)
          response = data['response'] || {}
          usage = response['usage'] || {}

          Chunk.new(
            role: :assistant,
            content: '',
            model_id: response['model'],
            input_tokens: usage['input_tokens'],
            output_tokens: usage['output_tokens'],
            cached_tokens: usage.dig('input_tokens_details', 'cached_tokens'),
            cache_creation_tokens: usage.dig('input_tokens_details', 'cache_write_tokens') || 0,
            thinking_tokens: usage.dig('output_tokens_details', 'reasoning_tokens')
          )
        end

        def response_event_error_message(data)
          data.dig('response', 'error', 'message') || data.dig('error', 'message') || 'OpenAI response failed'
        end
      end
    end
  end
end
