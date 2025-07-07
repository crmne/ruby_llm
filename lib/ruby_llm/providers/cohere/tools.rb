# frozen_string_literal: true

module RubyLLM
  module Providers
    module Cohere
      # Tools methods of the Cohere API integration
      # - https://docs.cohere.com/reference/chat#request.body.tools
      # - https://docs.cohere.com/docs/tool-use-overview
      module Tools
        module_function

        def tool_for(tool)
          {
            type: 'function',
            function: {
              name: tool.name,
              description: tool.description,
              parameters: {
                type: 'object',
                properties: tool.parameters.transform_values { |param| param_schema(param) },
                required: tool.parameters.select { |_, p| p.required }.keys
              }
            }
          }
        end

        def param_schema(param)
          {
            type: param.type,
            description: param.description
          }.compact
        end

        def format_tool_calls(tool_calls)
          return nil unless tool_calls&.any?

          tool_calls.map do |_, tc|
            {
              id: tc.id,
              type: 'function',
              function: {
                name: tc.name,
                arguments: tc.arguments.is_a?(Hash) ? tc.arguments.to_json : tc.arguments
              }
            }
          end
        end

        def parse_tool_calls(tool_calls, parse_arguments: true) # rubocop:disable Metrics/PerceivedComplexity
          return nil unless tool_calls&.any?

          tool_calls.to_h do |tc|
            arguments = if parse_arguments
                          raw_args = tc.dig('function', 'arguments')
                          if raw_args.is_a?(String)
                            JSON.parse(raw_args)
                          else
                            raw_args || {}
                          end
                        else
                          tc.dig('function', 'arguments')
                        end

            [
              tc['id'],
              ToolCall.new(
                id: tc['id'],
                name: tc.dig('function', 'name'),
                arguments: arguments
              )
            ]
          end
        end

        def format_tool_call(msg)
          # Format assistant message with tool calls for Cohere
          {
            role: 'assistant',
            tool_calls: format_tool_calls(msg.tool_calls)
          }.compact
        end

        def format_tool_result(msg)
          # Format tool result message for Cohere
          {
            role: 'tool',
            tool_call_id: msg.tool_call_id,
            content: msg.content
          }
        end
      end
    end
  end
end
