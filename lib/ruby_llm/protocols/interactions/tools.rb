# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Interactions
      module Tools # :nodoc:
        module_function

        def render_interaction_tools(tools)
          tools.values.map do |tool|
            parameters = tool.parameters_schema ||
                         Tool::SchemaDefinition.from_parameters(tool.declared_parameters)&.json_schema
            Support::Utils.deep_merge({ type: 'function', name: tool.name, description: tool.description,
                                        parameters: parameters }.compact, tool.provider_options)
          end
        end

        def render_interaction_choice(choice)
          return 'any' if choice == :required
          return choice.to_s if %i[auto none].include?(choice)

          { allowed_tools: { mode: 'any', tools: [choice.to_s] } }
        end

        def parse_interaction_calls(steps)
          steps.select { |step| step['type'] == 'function_call' }.to_h do |step|
            [step.fetch('id'), ToolCall.new(id: step.fetch('id'), name: step.fetch('name'),
                                            arguments: parse_interaction_arguments(step['arguments']),
                                            thought_signature: step['signature'])]
          end
        end

        def parse_interaction_arguments(arguments)
          return {} if arguments.nil? || (arguments.is_a?(String) && arguments.empty?)

          arguments.is_a?(String) ? JSON.parse(arguments) : arguments
        rescue JSON::ParserError => e
          raise ToolCallParseError.new(finish_reason: :tool_calls), cause: e
        end

        def parse_interaction_server_calls(steps)
          steps.filter_map do |step|
            type = step['type'].to_s
            next unless type.end_with?('_call', '_result') && !type.start_with?('function_')

            ServerToolCall.new(type: type, id: step['id'] || step['call_id'], name: step['name'],
                               input: step['arguments'], result: step['result'], raw: step)
          end
        end
      end
    end
  end
end
