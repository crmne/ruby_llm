module RubyLLM
  module Providers
    module Mistral
      # Handles function calling for Mistral models
      module Tools
        module_function

        # Moved from chat.rb
        def render_tool(tool)
          # Normalize the tool name to ensure consistency
          normalized_name = tool.name.to_s.downcase.gsub(/[^a-z0-9_]/, '_')
          
          {
            type: 'function',
            function: {
              name: normalized_name,
              description: tool.description,
              parameters: {
                type: 'object',
                properties: tool.parameters.transform_values { |param| param_schema(param) },
                required: tool.parameters.select { |_, p| p.required }.keys
              }
            }
          }
        end

        # Moved from chat.rb
        def param_schema(param)
          {
            type: param.type,
            description: param.description
          }.compact
        end

        def render_tool_choice(tool_choice)
          return 'none' if tool_choice == :none
          return 'auto' if tool_choice == :auto
          return 'any' if tool_choice == :any

          {
            type: 'function',
            function: { name: tool_choice }
          }
        end

        # Updated to match OpenAI's implementation pattern
        def parse_tool_calls(tool_calls)
          return {} unless tool_calls

          tool_calls.each_with_object({}) do |tool_call, hash|
            name = tool_call.dig('function', 'name')
            arguments = tool_call.dig('function', 'arguments')
            arguments = JSON.parse(arguments) if arguments.is_a?(String)

            hash[normalize_tool_name(name)] = ToolCall.new(
              id: tool_call['id'],
              name: name,
              arguments: arguments
            )
          end
        end

        def normalize_tool_name(name)
          name.to_s.downcase.gsub(/[^a-z0-9_]/, '_').to_sym
        end

        # Moved from chat.rb and streaming.rb
        def parse_tool_arguments(args)
          return {} if args.nil? || args.empty?
          return args unless args.is_a?(String)

          # Try to parse the arguments string as JSON
          begin
            JSON.parse(args)
          rescue JSON::ParserError
            # If parsing fails, return the original string
            args
          end
        end

        # Add method to format tool calls for request payload (stringify arguments)
        def format_tool_calls(tool_calls)
          return nil unless tool_calls&.any?

          # Convert to the expected format for the API
          tool_calls.map do |_, tc|
            {
              id: tc.id,
              type: 'function',
              function: {
                name: tc.name,
                arguments: tc.arguments.is_a?(String) ? tc.arguments : JSON.generate(tc.arguments || {})
              }
            }
          end
        end
      end
    end
  end
end
