# frozen_string_literal: true

module RubyLLM
  module Providers
    module Cohere
      # Streaming methods of the Cohere API integration
      # - https://docs.cohere.com/docs/streaming
      module Streaming
        private

        def stream_url
          completion_url
        end

        def build_chunk(data)
          Chunk.new(
            role: :assistant,
            model_id: extract_model_id(data),
            content: extract_content(data),
            input_tokens: extract_input_tokens(data),
            output_tokens: extract_output_tokens(data),
            tool_calls: extract_tool_calls(data)
          )
        end

        def extract_model_id(data)
          data['response_id'] || data['id']
        end

        def extract_content(data)
          case data['type']
          when 'content-delta'
            data.dig('delta', 'message', 'content', 'text')
          when 'message-end'
            # Final message content
            data.dig('delta', 'message', 'content', 0, 'text')
          end
        end

        def extract_input_tokens(data)
          return unless data['type'] == 'message-end'

          data.dig('delta', 'usage', 'tokens', 'input_tokens')
        end

        def extract_output_tokens(data)
          return unless data['type'] == 'message-end'

          data.dig('delta', 'usage', 'tokens', 'output_tokens')
        end

        def extract_tool_calls(data)
          case data['type']
          when 'tool-call-start'
            tool_call_data = data.dig('delta', 'message', 'tool_calls')
            return {} unless tool_call_data

            tool_call = ToolCall.new(
              id: tool_call_data['id'],
              name: tool_call_data.dig('function', 'name'),
              arguments: tool_call_data.dig('function', 'arguments') || ''
            )
            { tool_call.id => tool_call }
          when 'tool-call-delta'
            # Handle streaming tool call arguments
            argument_delta = data.dig('delta', 'message', 'tool_calls', 'function', 'arguments')
            return {} unless argument_delta

            { nil => ToolCall.new(id: nil, name: nil, arguments: argument_delta) }
          when 'message-end'
            tool_calls = data.dig('delta', 'message', 'tool_calls')
            return {} unless tool_calls

            result = {}
            tool_calls.each do |call|
              tool_call = ToolCall.new(
                id: call['id'],
                name: call.dig('function', 'name'),
                arguments: call.dig('function', 'parameters')
              )
              result[tool_call.id] = tool_call
            end
            result
          else
            {}
          end
        end

        def parse_streaming_error(data)
          error_data = JSON.parse(data)
          return unless error_data['type'] == 'error'

          message = error_data.dig('error', 'message') || 'Unknown error'
          [500, message]
        rescue JSON::ParserError
          [500, 'Failed to parse error response']
        end
      end
    end
  end
end
