# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Tools methods for the AWS Bedrock API implementation
      module Tools
        module_function

        def tool_for(tool)
          {
            type: 'function',
            function: {
              name: tool.name,
              description: tool.description,
              parameters: tool.parameters
            }
          }
        end

        def parse_tool_calls(tool_calls, parse_arguments: true)
          return {} unless tool_calls

          tool_calls.each_with_object({}) do |call, hash|
            function_args = call['function']['arguments']
            hash[call['id']] = ToolCall.new(
              id: call['id'],
              name: call['function']['name'],
              arguments: parse_arguments ? parse_arguments(function_args) : function_args
            )
          end
        end

        private

        def parse_arguments(arguments)
          return {} unless arguments

          case arguments
          when String
            JSON.parse(arguments)
          when Hash
            arguments
          else
            {}
          end
        rescue JSON::ParserError
          {}
        end
      end
    end
  end
end
