# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Responses
      # Tools methods of the OpenAI Responses API. Function definitions are
      # flat rather than nested under a `function` key.
      module Tools
        module_function

        NATIVE_TOOL_SEARCH = { type: 'tool_search' }.freeze

        def tool_for(tool)
          definition = {
            type: 'function',
            name: tool.name,
            description: tool.description,
            parameters: ChatCompletions::Tools.parameters_schema_for(tool),
            strict: false
          }
          definition[:defer_loading] = true if deferred?(tool)

          return definition if tool.provider_options.empty?

          RubyLLM::Support::Utils.deep_merge(definition, tool.provider_options)
        end

        def format_tools(tools, provider_tools: [])
          formatted = tools.map { |_, tool| tool_for(tool) }
          if formatted.any? { |entry| entry[:defer_loading] } && !search_tool_configured?(provider_tools)
            formatted << NATIVE_TOOL_SEARCH.dup
          end
          formatted
        end

        def deferred?(tool)
          tool.is_a?(RubyLLM::Tool::Registration) && tool.deferred?
        end

        def replay_search?(tools, provider_tools)
          tools.values.any? { |tool| deferred?(tool) } || search_tool_configured?(provider_tools)
        end

        def search_tool_configured?(provider_tools)
          provider_tools.any? { |entry| (entry[:type] || entry['type']) == NATIVE_TOOL_SEARCH[:type] }
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
