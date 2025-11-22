# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Tools methods of the OpenAI API integration
      module Tools
        module_function

        EMPTY_PARAMETERS_SCHEMA = {
          'type' => 'object',
          'properties' => {},
          'required' => [],
          'additionalProperties' => false,
          'strict' => true
        }.freeze

        def parameters_schema_for(tool)
          tool.params_schema ||
            schema_from_parameters(tool.parameters)
        end

        def schema_from_parameters(parameters)
          schema_definition = RubyLLM::Tool::SchemaDefinition.from_parameters(parameters)
          schema_definition&.json_schema || EMPTY_PARAMETERS_SCHEMA
        end

        def tool_for(tool)
          parameters_schema = parameters_schema_for(tool)

          definition = {
            type: 'function',
            function: {
              name: tool.name,
              description: tool.description,
              parameters: parameters_schema
            }
          }

          return definition if tool.provider_params.empty?

          RubyLLM::Utils.deep_merge(definition, tool.provider_params)
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
                arguments: JSON.generate(tc.arguments)
              }
            }
          end
        end

        def parse_tool_call_arguments(tool_call)
          arguments = tool_call.dig('function', 'arguments')

          if arguments.nil? || arguments.empty?
            {}
          else
            JSON.parse(arguments)
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
                             parse_tool_call_arguments(tc)
                           else
                             tc.dig('function', 'arguments')
                           end
              )
            ]
          end
        end
      end
    end
  end
end
