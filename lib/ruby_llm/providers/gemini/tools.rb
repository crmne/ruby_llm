# frozen_string_literal: true

module RubyLLM
  module Providers
    class Gemini
      # Tools methods for the Gemini API implementation
      module Tools
        def format_tools(tools)
          return [] if tools.empty?

          [{
            functionDeclarations: tools.values.map { |tool| function_declaration_for(tool) }
          }]
        end

        def format_tool_call(msg)
          [{
            functionCall: {
              name: msg.tool_calls.values.first.name,
              args: msg.tool_calls.values.first.arguments
            }
          }]
        end

        def format_tool_result(msg)
          [{
            functionResponse: {
              name: msg.tool_call_id,
              response: {
                name: msg.tool_call_id,
                content: Media.format_content(msg.content)
              }
            }
          }]
        end

        def extract_tool_calls(data)
          return nil unless data

          candidate = data.is_a?(Hash) ? data.dig('candidates', 0) : nil
          return nil unless candidate

          parts = candidate.dig('content', 'parts')
          return nil unless parts.is_a?(Array)

          function_call_part = parts.find { |p| p['functionCall'] }
          return nil unless function_call_part

          function_data = function_call_part['functionCall']
          return nil unless function_data

          id = SecureRandom.uuid

          {
            id => ToolCall.new(
              id: id,
              name: function_data['name'],
              arguments: function_data['args']
            )
          }
        end

        private

        def function_declaration_for(tool)
          declaration = {
            name: tool.name,
            description: tool.description,
            parameters: tool.parameters.any? ? format_parameters(tool.parameters) : nil
          }.compact

          return declaration if tool.provider_params.empty?

          RubyLLM::Utils.deep_merge(declaration, tool.provider_params)
        end

        def format_parameters(parameters)
          {
            type: 'OBJECT',
            properties: parameters.transform_values do |param|
              {
                type: param_type_for_gemini(param.type),
                description: param.description
              }.compact
            end,
            required: parameters.select { |_, p| p.required }.keys.map(&:to_s)
          }
        end

        def param_type_for_gemini(type)
          case type.to_s.downcase
          when 'integer', 'number', 'float' then 'NUMBER'
          when 'boolean' then 'BOOLEAN'
          when 'array' then 'ARRAY'
          when 'object' then 'OBJECT'
          else 'STRING'
          end
        end
      end
    end
  end
end
