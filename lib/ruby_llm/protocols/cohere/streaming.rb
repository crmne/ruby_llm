# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Cohere
      # Streaming methods of the Cohere v2 API integration
      module Streaming
        private

        def stream_url
          completion_url
        end

        def build_chunk(data)
          type = data['type']
          track_content_lengths(data, type)

          Chunk.new(
            role: :assistant,
            model: model&.id,
            content: extract_content_delta(data, type),
            citations: extract_citations_delta(data, type),
            thinking: Thinking.build(text: extract_thinking_delta(data, type)),
            tool_calls: extract_tool_calls(data, type),
            finish_reason: data.dig('delta', 'finish_reason'),
            **stream_usage(data.dig('delta', 'usage'))
          )
        end

        # Citation spans are offsets into their own content block, so the
        # running length of every earlier text block is what turns them into
        # offsets into the accumulated response content.
        def track_content_lengths(data, type)
          return unless type == 'content-delta'

          text = data.dig('delta', 'message', 'content', 'text')
          return unless text

          @stream_content_lengths ||= Hash.new(0)
          @stream_content_lengths[data['index']] += text.length
        end

        def content_offset(index)
          return 0 unless @stream_content_lengths

          @stream_content_lengths.sum { |block_index, length| block_index < index ? length : 0 }
        end

        def extract_content_delta(data, type)
          data.dig('delta', 'message', 'content', 'text') if type == 'content-delta'
        end

        def extract_thinking_delta(data, type)
          case type
          when 'content-delta' then data.dig('delta', 'message', 'content', 'thinking')
          when 'tool-plan-delta' then data.dig('delta', 'message', 'tool_plan')
          end
        end

        def extract_citations_delta(data, type)
          return nil unless type == 'citation-start'

          citation = data.dig('delta', 'message', 'citations')
          return nil unless citation

          index = citation['content_index'] || 0
          [Chat.parse_citation(citation, { index => content_offset(index) })]
        end

        def extract_tool_calls(data, type)
          case type
          when 'tool-call-start' then stream_tool_call_start(data)
          when 'tool-call-delta' then stream_tool_call_delta(data)
          end
        end

        def stream_tool_call_start(data)
          tool_call = data.dig('delta', 'message', 'tool_calls')
          return nil unless tool_call

          {
            data['index'] => ToolCall.new(
              id: tool_call['id'],
              name: tool_call.dig('function', 'name'),
              arguments: tool_call.dig('function', 'arguments').to_s
            )
          }
        end

        def stream_tool_call_delta(data)
          arguments = data.dig('delta', 'message', 'tool_calls', 'function', 'arguments')
          return nil unless arguments

          { data['index'] => ToolCall.new(id: nil, name: nil, arguments: arguments) }
        end

        def stream_usage(usage)
          return {} unless usage

          Chat.usage_tokens(usage)
        end
      end
    end
  end
end
