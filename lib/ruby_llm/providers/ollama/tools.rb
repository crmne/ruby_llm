# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Tools methods of the Ollama API integration
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

        def parse_tool_calls(tool_calls)
          return nil unless tool_calls&.any?

          tool_calls.to_h do |tc|
            tc = tc['function'] if tc['function']
            name = tc['name']
            next [nil, nil] unless name =~ /\S/

            [
              name,
              ToolCall.new(
                id: name,
                name: name,
                arguments: tc['arguments']
              )
            ]
          end.compact
        end

      end
    end
  end
end
