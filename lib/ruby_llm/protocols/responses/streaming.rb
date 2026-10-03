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
          'too_many_requests' => 429,
          'insufficient_quota' => 429
        }.freeze

        module_function

        def stream_response(...)
          @citation_content_lengths = Hash.new(0)
          super
        end

        def build_chunk(data)
          case data['type']
          when 'response.output_text.delta', 'response.refusal.delta'
            build_text_chunk(data)
          when 'response.reasoning_summary_text.delta'
            chunk thinking: Thinking.build(text: data['delta'])
          when 'response.reasoning_summary_part.added'
            build_reasoning_summary_part_chunk(data)
          when 'response.output_text.annotation.added'
            build_annotation_chunk(data)
          when 'response.output_item.added'
            build_item_added_chunk(data)
          when 'response.function_call_arguments.delta'
            chunk tool_calls: { data['output_index'] => ToolCall.new(id: nil, name: nil, arguments: data['delta']) }
          when 'response.output_item.done'
            build_item_done_chunk(data)
          when 'response.completed', 'response.incomplete'
            build_final_chunk(data)
          when 'response.failed'
            raise_failed_response(data['response'] || {})
          else
            chunk
          end
        end

        def build_text_chunk(data)
          @citation_content_lengths ||= Hash.new(0)
          @citation_content_lengths[citation_content_position(data)] += data['delta'].to_s.length
          chunk content: data['delta']
        end

        def build_annotation_chunk(data)
          position = citation_content_position(data)
          offset = (@citation_content_lengths || {}).sum do |key, length|
            (key <=> position).negative? ? length : 0
          end

          chunk citations: offset_citations(parse_annotations([data['annotation']], nil), offset, nil)
        end

        def citation_content_position(data)
          [data.fetch('output_index', 0), data.fetch('content_index', 0)]
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
                tool_calls: parse_tool_approvals(output, finish_reason: parse_finish_reason(response)),
                finish_reason: parse_finish_reason(response),
                citations: parse_citations(response, output, nil),
                server_tool_calls: server_tool_calls,
                raw_content: server_tool_calls.any? ? output : nil,
                **parse_usage(response['usage'] || {})
        end

        def raise_failed_response(response)
          body = { 'error' => response['error'] }
          raise_stream_error(JSON.generate(body), body, nil)
        end

        # OpenAI reports a stream error as a flat event carrying a code. Azure
        # nests the code and type under an error object, as a failed response
        # and Chat Completions do.
        def parse_streaming_error(data)
          event = JSON.parse(data)
          error = stream_error(event)
          return super unless error

          [ERROR_STATUSES[error['code']] || ERROR_STATUSES.fetch(error['type'], 400), error['message']]
        end

        def stream_error(event)
          return unless event.is_a?(Hash)
          return event['error'] if event['error'].is_a?(Hash)

          event if event['type'] == 'error'
        end

        def chunk(content: nil, **attributes)
          Chunk.new(role: :assistant, content: content, **attributes)
        end
      end
    end
  end
end
