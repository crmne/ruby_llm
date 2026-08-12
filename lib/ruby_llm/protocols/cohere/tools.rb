# frozen_string_literal: true

require 'json'

module RubyLLM
  module Protocols
    class Cohere
      # Tools methods of the Cohere v2 API integration
      module Tools
        EMPTY_PARAMETERS_SCHEMA = {
          'type' => 'object',
          'properties' => {},
          'required' => []
        }.freeze

        module_function

        def function_for(tool)
          definition = {
            type: 'function',
            function: {
              name: tool.name,
              description: tool.description,
              parameters: parameters_schema_for(tool)
            }.compact
          }

          return definition if tool.provider_options.empty?

          RubyLLM::Utils.deep_merge(definition, tool.provider_options)
        end

        # Cohere takes plain JSON Schema here and controls strictness with the
        # request's own strict_tools flag, so the OpenAI strict keyword goes.
        def parameters_schema_for(tool)
          schema = tool.parameters_schema ||
                   RubyLLM::Tool::SchemaDefinition.from_parameters(tool.declared_parameters)&.json_schema
          return EMPTY_PARAMETERS_SCHEMA unless schema

          schema = RubyLLM::Utils.deep_dup(schema)
          schema.delete(:strict)
          schema.delete('strict')
          schema
        end

        # Cohere only forces tool use on or off; it cannot pin a named tool.
        def build_tool_choice(choice)
          case choice
          when nil, :auto then nil
          when :none then 'NONE'
          when :required then 'REQUIRED'
          else
            raise ArgumentError,
                  "Cohere tool choice accepts :auto, :required, or :none, got #{choice.inspect}"
          end
        end

        def format_tool_calls(tool_calls)
          tool_calls.map do |_, tool_call|
            {
              id: tool_call.id,
              type: 'function',
              function: {
                name: tool_call.name,
                arguments: JSON.generate(tool_call.arguments)
              }
            }
          end
        end

        def format_tool_result(msg)
          {
            role: 'tool',
            tool_call_id: msg.tool_call_id,
            content: format_tool_result_content(msg)
          }
        end

        # Search results become document content blocks, the shape Cohere
        # cites tool output against.
        def format_tool_result_content(msg)
          search_results = RubyLLM::SearchResults.from_content(msg.content)
          return document_blocks(search_results) if search_results

          msg.content.to_s
        end

        def document_blocks(search_results)
          search_results.results.map.with_index do |result, index|
            {
              type: 'document',
              document: {
                id: result[:url] || "tool:#{index}",
                data: { title: result[:title], text: result[:text], url: result[:url] }.compact
              }
            }
          end
        end

        def parse_tool_calls(tool_calls, response: nil, finish_reason: nil)
          return nil unless tool_calls&.any?

          tool_calls.to_h do |tool_call|
            [
              tool_call['id'],
              ToolCall.new(
                id: tool_call['id'],
                name: tool_call.dig('function', 'name'),
                arguments: parse_arguments(tool_call.dig('function', 'arguments'), response, finish_reason)
              )
            ]
          end
        end

        def parse_arguments(arguments, response, finish_reason)
          return {} if arguments.nil? || arguments.empty?

          JSON.parse(arguments)
        rescue JSON::ParserError => e
          raise ToolCallParseError.new(response: response, finish_reason: finish_reason), cause: e
        end
      end
    end
  end
end
