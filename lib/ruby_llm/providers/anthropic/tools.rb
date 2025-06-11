# frozen_string_literal: true

module RubyLLM
  module Providers
    module Anthropic
      # Tools methods of the Anthropic API integration
      module Tools
        module_function

        def find_tool_use(blocks)
          blocks.find { |c| c['type'] == 'tool_use' }
        end

        def format_tool_call(msg)
          tool_call = msg.tool_calls.values.first

          content = []
          content << Media.format_text(msg.content) unless msg.content.nil? || msg.content.empty?
          content << format_tool_use_block(tool_call)

          {
            role: 'assistant',
            content:
          }
        end

        def format_tool_result(msg)
          {
            role: 'user',
            content: [format_tool_result_block(msg)]
          }
        end

        def format_tool_use_block(tool_call)
          {
            type: 'tool_use',
            id: tool_call.id,
            name: tool_call.name,
            input: tool_call.arguments
          }
        end

        def format_tool_result_block(msg)
          {
            type: 'tool_result',
            tool_use_id: msg.tool_call_id,
            content: msg.content
          }
        end

        def function_for(tool)
          {
            name: tool.name,
            description: tool.description,
            input_schema: {
              type: 'object',
              properties: clean_parameters(tool.parameters),
              required: required_parameters(tool.parameters)
            }
          }
        end

        def extract_tool_calls(data)
          if json_delta?(data)
            { nil => ToolCall.new(id: nil, name: nil, arguments: data.dig('delta', 'partial_json')) }
          else
            parse_tool_calls(data['content_block'])
          end
        end

        def parse_tool_calls(content_block)
          return nil unless content_block && content_block['type'] == 'tool_use'

          {
            content_block['id'] => ToolCall.new(
              id: content_block['id'],
              name: content_block['name'],
              arguments: content_block['input']
            )
          }
        end

        def clean_parameters(parameters)
          parameters.transform_values do |param|
            {
              type: param.type,
              description: param.description
            }.compact
          end
        end

        def required_parameters(parameters)
          parameters.select { |_, param| param.required }.keys
        end
      end
    end
  end
end
