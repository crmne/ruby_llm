# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Responses
      # Tools methods of the OpenAI Responses API. Function definitions are
      # flat rather than nested under a `function` key.
      module Tools
        module_function

        def tool_for(tool)
          definition = {
            type: 'function',
            name: tool.name,
            description: tool.description,
            parameters: ChatCompletions::Tools.parameters_schema_for(tool)
          }

          return definition if tool.provider_params.empty?

          RubyLLM::Utils.deep_merge(definition, tool.provider_params)
        end

        def build_tool_choice(tool_choice)
          case tool_choice
          when :auto, :none, :required
            tool_choice
          else
            {
              type: 'function',
              name: tool_choice
            }
          end
        end
      end
    end
  end
end
