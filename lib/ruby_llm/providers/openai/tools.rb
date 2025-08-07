# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Tools methods of the OpenAI API integration
      module Tools
        module_function

        def chat_tool_for(tool)
          {
            type: 'function',
            function: {
              name: tool.name,
              description: tool.description,
              parameters: tool_parameters_for(tool)
            }
          }
        end

        def response_tool_for(tool)
          {
            type: 'function',
            name: tool.name,
            description: tool.description,
            parameters: tool_parameters_for(tool)
          }
        end

        def param_schema(param)
          {
            type: param.type,
            description: param.description
          }.compact
        end

        def tool_parameters_for(tool)
          {
            type: 'object',
            properties: tool.parameters.transform_values { |param| param_schema(param) },
            required: tool.parameters.select { |_, p| p.required }.keys
          }
        end

        def format_tool_calls(tool_calls)
          return nil unless tool_calls&.any?

          tool_calls.map do |_, tc|
            {
              id: tc.id,
              type: 'function',
              function: {
                name: tc.name,
                arguments: JSON.generate(tc.arguments)
              }
            }
          end
        end

        def parse_tool_calls(tool_calls, parse_arguments: true)
          return nil unless tool_calls&.any?

          tool_calls.to_h do |tc|
            [
              tc['id'],
              ToolCall.new(
                id: tc['id'],
                name: tc.dig('function', 'name'),
                arguments: if parse_arguments
                             if tc.dig('function', 'arguments').empty?
                               {}
                             else
                               JSON.parse(tc.dig('function',
                                                 'arguments'))
                             end
                           else
                             tc.dig('function', 'arguments')
                           end
              )
            ]
          end
        end

        def parse_response_tool_calls(outputs)
          # TODO: implement the other & built-in tools
          # 'web_search_call', 'file_search_call', 'image_generation_call',
          # 'code_interpreter_call', 'local_shell_call', 'mcp_call',
          # 'mcp_list_tools', 'mcp_approval_request'
          outputs.select { |o| o['type'] == 'function_call' }.to_h do |o|
            [o['id'], ToolCall.new(
              id: o['call_id'],
              name: o['name'],
              arguments: JSON.parse(o['arguments'])
            )]
          end
        end
      end
    end
  end
end
