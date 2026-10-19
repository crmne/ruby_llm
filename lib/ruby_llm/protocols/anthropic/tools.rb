# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Anthropic
      # Tools methods of the Anthropic API integration
      module Tools
        module_function

        NATIVE_TOOL_SEARCH = {
          type: 'tool_search_tool_bm25_20251119',
          name: 'tool_search_tool_bm25'
        }.freeze

        def find_tool_uses(blocks)
          blocks.select { |c| c['type'] == 'tool_use' }
        end

        def tool_search_block?(block)
          return true if block['type'] == 'tool_search_tool_result'

          block['type'] == 'server_tool_use' && block['name'].to_s.start_with?('tool_search_tool_')
        end

        def render_tool_result(msg, tool_call: nil)
          {
            role: 'user',
            content: [render_tool_result_block(msg, tool_call:)]
          }
        end

        def render_tool_result_block(msg, tool_call: nil)
          block = {
            type: 'tool_result',
            tool_use_id: msg.provider_call_id,
            content: render_tool_result_content(msg)
          }
          return block unless tool_call&.namespace

          block[:toolset_name] = tool_call.namespace
          if (error = msg.tool_error_message)
            block[:is_error] = true
            error = 'Not executed: an earlier computer action in this turn failed.' if msg.tool_result_skipped? &&
                                                                                       tool_call.namespace == 'computer'
            block[:content] = [{ type: 'text', text: error.to_s }]
          end
          block
        end

        def render_tool_result_content(msg)
          search_results = RubyLLM::SearchResults.from_content(msg.content)
          return search_results.results.map { |result| search_result_block(result) } if search_results

          content = msg.content
          content = nil if content&.strip&.empty?
          content = '(no output)' if content.nil? && msg.attachments.empty?

          Media.render_content(content, msg.attachments)
        end

        def search_result_block(result)
          {
            type: 'search_result',
            source: result[:url] || result[:title],
            title: result[:title],
            content: [{ type: 'text', text: result[:text] }],
            citations: { enabled: true }
          }
        end

        def render_tools(tools)
          tools.values.reject(&:namespace).map { |tool| function_for(tool) }
        end

        def function_for(tool)
          input_schema = tool.parameters_schema ||
                         RubyLLM::Tool::SchemaDefinition.from_parameters(tool.declared_parameters)&.json_schema

          declaration = {
            name: tool.name,
            description: tool.description,
            input_schema: input_schema || default_input_schema
          }
          declaration[:defer_loading] = true if deferred?(tool)

          RubyLLM::Support::Utils.deep_merge(declaration, tool.provider_options)
        end

        def deferred?(tool)
          tool.is_a?(RubyLLM::Tool::Deferred)
        end

        # The API requires a search tool next to deferred tools, and rejects
        # search blocks in the history of a request that declares none.
        def apply_tool_search(payload)
          tools = Array(payload[:tools])
          return payload if tools.any? { |tool| search_tool?(tool) }
          return payload.merge(tools: tools + [NATIVE_TOOL_SEARCH.dup]) if defers_loading?(tools)

          payload.merge(messages: without_tool_search_blocks(payload[:messages]))
        end

        def defers_loading?(tools)
          tools.any? { |tool| tool[:defer_loading] || tool['defer_loading'] }
        end

        def search_tool?(tool)
          (tool[:type] || tool['type']).to_s.start_with?('tool_search_tool_')
        end

        def without_tool_search_blocks(messages)
          messages.filter_map do |message|
            next message unless message[:content].is_a?(Array)

            content = message[:content].reject { |block| tool_search_block?(block) }
            message.merge(content:) unless content.empty?
          end
        end

        def extract_tool_calls(data)
          if json_delta?(data)
            parse_tool_call_delta(data)
          elsif content_block_start?(data)
            parse_tool_call_start(data)
          else
            parse_tool_calls(data['content_block'])
          end
        end

        def parse_tool_call_delta(data)
          { data['index'] => ToolCall.new(name: nil, arguments: data.dig('delta', 'partial_json')) }
        end

        def parse_tool_call_start(data)
          tool_calls = parse_tool_calls(data['content_block'])
          return tool_calls if tool_calls.nil? || data['index'].nil?

          { data['index'] => tool_calls.values.first }
        end

        def content_block_start?(data)
          data['type'] == 'content_block_start'
        end

        def parse_tool_calls(content_blocks)
          content_blocks = [content_blocks] unless content_blocks.is_a?(Array)

          calls = content_blocks.filter_map do |block|
            next unless block && block['type'] == 'tool_use'

            ToolCall.new(
              provider_call_id: block['id'],
              name: block['name'],
              namespace: block['toolset_name'],
              sequential: !block['toolset_name'].nil?,
              arguments: block['input']
            )
          end

          ToolCall.index(calls, by: :provider_call_id) unless calls.empty?
        end

        def default_input_schema
          {
            'type' => 'object',
            'properties' => {},
            'required' => [],
            'additionalProperties' => false,
            'strict' => true
          }
        end

        def build_tool_choice(tool_prefs)
          tool_choice = tool_prefs[:choice]
          calls_in_response = tool_prefs[:calls]
          tool_choice = :auto if tool_choice.nil?

          {
            type: case tool_choice
                  when :auto, :none
                    tool_choice
                  when :required
                    :any
                  else
                    :tool
                  end
          }.tap do |tc|
            tc[:name] = tool_choice if tc[:type] == :tool
            tc[:disable_parallel_tool_use] = calls_in_response == :one if tc[:type] != :none && !calls_in_response.nil?
          end
        end
      end
    end
  end
end
