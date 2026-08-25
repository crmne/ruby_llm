# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Responses
      # Streaming methods of the OpenAI Responses API. Events are semantic:
      # each SSE data frame carries a `type` describing what changed.
      module Streaming
        ERROR_STATUSES = {
          'server_error' => 500,
          'rate_limit_exceeded' => 429,
          'insufficient_quota' => 429
        }.freeze

        module_function

        def build_chunk(data)
          case data['type']
          when 'response.output_text.delta', 'response.refusal.delta'
            chunk content: data['delta']
          when 'response.reasoning_summary_text.delta'
            chunk thinking: Thinking.build(text: data['delta'])
          when 'response.reasoning_summary_part.added'
            build_reasoning_summary_part_chunk(data)
          when 'response.output_text.annotation.added'
            chunk citations: parse_annotations([data['annotation']], nil)
          when 'response.output_item.added'
            build_item_added_chunk(data)
          when 'response.function_call_arguments.delta'
            chunk tool_calls: { data['output_index'] => ToolCall.new(id: nil, name: nil, arguments: data['delta']) }
          when 'response.output_item.done'
            build_item_done_chunk(data)
          when 'response.completed', 'response.incomplete'
            build_final_chunk(data)
          when 'response.failed'
            raise Error, data.dig('response', 'error', 'message')
          else
            chunk
          end
        end

        def build_reasoning_summary_part_chunk(data)
          return chunk unless data['summary_index'].positive?

          chunk thinking: Thinking.build(text: "\n\n")
        end

        def build_item_added_chunk(data)
          item = data['item']
          return chunk unless item['type'] == 'function_call'

          chunk tool_calls: {
            data['output_index'] => ToolCall.new(id: item['call_id'], name: item['name'], arguments: +'')
          }
        end

        def build_item_done_chunk(data)
          item = data['item']
          return chunk unless item['type'] == 'reasoning' && item['encrypted_content']

          chunk thinking: Thinking.build(text: nil, signature: item['encrypted_content'])
        end

        def build_final_chunk(data)
          response = data['response'] || {}
          output = response['output'] || []
          server_tool_calls = parse_server_tool_items(output)

          chunk model: response['model'],
                finish_reason: response.dig('incomplete_details', 'reason'),
                server_tool_calls: server_tool_calls,
                raw_content: server_tool_calls.any? ? output : nil,
                **parse_usage(response['usage'] || {})
        end

        # Responses reports a stream error as a flat event carrying a code,
        # where Chat Completions nests type and message under an error object.
        def parse_streaming_error(data)
          event = JSON.parse(data)
          return super unless event.is_a?(Hash) && event['type'] == 'error'

          [ERROR_STATUSES.fetch(event['code'], 400), event['message']]
        end

        def chunk(content: nil, **attributes)
          Chunk.new(role: :assistant, content: content, **attributes)
        end
      end
    end
  end
end
