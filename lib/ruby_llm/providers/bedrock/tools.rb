# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Tools methods for the AWS Bedrock API implementation
      module Tools
        module_function

        def tool_for(tool)
          {
            toolSpec: {
              name: tool.name,
              description: tool.description,
              inputSchema: {
                json: {
                  type: 'object',
                  properties: tool.parameters.transform_values { |param| param_schema(param) },
                  required: tool.parameters.select { |_, p| p.required }.keys
                }
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

        # Parse Bedrock converse toolUse blocks into ToolCall objects
        def parse_tool_calls(tool_use_blocks)
          return [] unless tool_use_blocks&.any?

          tool_use_blocks.map do |block|
            tool_use = block['toolUse']
            RubyLLM::ToolCall.new(
              id: tool_use['id'],
              name: tool_use['name'],
              arguments: tool_use['input']
            )
          end
        end
      end
    end
  end
end
