# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Responses
      # Streaming methods of the OpenAI Responses API. Events are semantic:
      # each SSE data frame carries a `type` describing what changed.
      module Streaming
        module_function

        def build_chunk(data)
          case data['type']
          when 'response.output_text.delta'
            chunk content: data['delta']
          when 'response.reasoning_summary_text.delta'
            chunk thinking: Thinking.build(text: data['delta'])
          when 'response.output_text.annotation.added'
            chunk citations: parse_annotations([data['annotation']], nil)
          when 'response.output_item.added'
            build_item_added_chunk(data)
          when 'response.function_call_arguments.delta'
            chunk tool_calls: { data['output_index'] => ToolCall.new(id: nil, name: nil, arguments: data['delta']) }
          when 'response.output_item.done'
            build_item_done_chunk(data)
          when 'response.completed'
            build_completed_chunk(data)
          else
            chunk
          end
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

        def build_completed_chunk(data)
          response = data['response'] || {}

          chunk model_id: response['model'],
                finish_reason: response.dig('incomplete_details', 'reason'),
                **parse_usage(response['usage'] || {})
        end

        def chunk(content: nil, **attributes)
          Chunk.new(role: :assistant, content: content, **attributes)
        end
      end
    end
  end
end
