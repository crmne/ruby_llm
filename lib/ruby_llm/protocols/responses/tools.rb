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

        def render_tools(tools)
          ordinary, namespaced = tools.values.partition { |tool| tool.namespace.nil? }
          groups = namespaced.group_by(&:namespace).map do |namespace, members|
            { type: 'namespace', name: namespace, description: members.filter_map(&:namespace_description).first,
              tools: members.map { |tool| tool_for(tool) } }.compact
          end
          ordinary.map { |tool| tool_for(tool) } + groups
        end

        def deferred?(tool)
          tool.is_a?(RubyLLM::Tool::Deferred)
        end

        # Tool search loads a deferred function declared outside any
        # namespace under a namespace of its own name, and the API refuses a
        # call to it that lacks the namespace.
        def namespace_searched_calls(input, tools)
          searched = tools.each_value.filter_map { |tool| tool.name.to_s if deferred?(tool) && tool.namespace.nil? }
          input.map { |item| searched_call?(item, searched) ? item.merge(namespace: item[:name]) : item }
        end

        def searched_call?(item, searched)
          item.is_a?(Hash) && item[:type] == 'function_call' && item[:namespace].nil? && searched.include?(item[:name])
        end

        # The API requires a search tool next to deferred tools, and rejects
        # search items in the input of a request that declares none.
        def apply_tool_search(payload)
          tools = Array(payload[:tools])
          return payload if tools.any? { |tool| search_tool?(tool) }
          return payload.merge(tools: tools + [NATIVE_TOOL_SEARCH.dup]) if defers_loading?(tools)

          payload.merge(input: payload[:input].reject do |item|
            Chat::TOOL_SEARCH_ITEM_TYPES.include?(item[:type] || item['type'])
          end)
        end

        def defers_loading?(tools)
          tools.any? do |tool|
            tool[:defer_loading] || tool['defer_loading'] || defers_loading?(Array(tool[:tools] || tool['tools']))
          end
        end

        def search_tool?(tool)
          (tool[:type] || tool['type']) == NATIVE_TOOL_SEARCH[:type]
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
