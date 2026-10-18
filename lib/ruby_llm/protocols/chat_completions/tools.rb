# frozen_string_literal: true

require 'json'

module RubyLLM
  module Protocols
    class ChatCompletions
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
          tool.parameters_schema ||
            schema_from_parameters(tool.declared_parameters)
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

          return definition if tool.provider_options.empty?

          RubyLLM::Support::Utils.deep_merge(definition, tool.provider_options)
        end

        def render_tool_calls(tool_calls)
          return nil unless tool_calls&.any?

          tool_calls.map do |_, tc|
            call = {
              id: tc.provider_call_id,
              type: 'function',
              function: {
                name: tc.name,
                arguments: JSON.generate(tc.arguments)
              }
            }
            if tc.thought_signature
              call[:extra_content] = {
                google: { thought_signature: tc.thought_signature }
              }
            end
            call
          end
        end

        def parse_tool_call_arguments(tool_call, response: nil, finish_reason: nil)
          arguments = tool_call.dig('function', 'arguments')

          if arguments.nil? || arguments.empty?
            {}
          else
            Hash(JSON.parse(arguments))
          end
        rescue JSON::ParserError, TypeError => e
          raise ToolCallParseError.for(response:, finish_reason:), cause: e
        end

        # Streaming deltas key by index so id-less argument fragments find
        # their call even when a delta batches or interleaves several calls;
        # complete responses key by id, which tool results join on.
        def parse_tool_calls(tool_calls, parse_arguments: true, response: nil, finish_reason: nil, stream_keys: false)
          return nil unless tool_calls&.any?

          calls = tool_calls.map do |tc|
            [
              tc['index'] || tc['id'],
              parse_tool_call(tc, parse_arguments:, response:, finish_reason:)
            ]
          end
          stream_keys ? calls.to_h : ToolCall.index(calls.map(&:last), by: :provider_call_id)
        end

        def parse_tool_call(call, parse_arguments:, response:, finish_reason:)
          arguments = if parse_arguments
                        parse_tool_call_arguments(call, response:, finish_reason:)
                      else
                        call.dig('function', 'arguments')
                      end
          ToolCall.new(provider_call_id: call['id'], name: call.dig('function', 'name'), arguments:,
                       thought_signature: parse_tool_call_thought_signature(call))
        end

        def build_tool_choice(tool_choice)
          case tool_choice
          when :auto, :none, :required
            tool_choice
          else
            {
              type: 'function',
              function: {
                name: tool_choice
              }
            }
          end
        end

        def parse_tool_call_thought_signature(tool_call)
          tool_call.dig('extra_content', 'google', 'thought_signature')
        end
      end
    end
  end
end
