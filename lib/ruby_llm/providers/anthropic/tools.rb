# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Tools methods of the Anthropic API integration
      module Tools
        module_function

        def find_tool_uses(blocks)
          blocks.select { |c| c['type'] == 'tool_use' }
        end

        def format_tool_call(msg)
          return { role: 'assistant', content: msg.content.value } if msg.content.is_a?(RubyLLM::Content::Raw)

          content = []

          content << Media.format_text(msg.content) unless msg.content.nil? || msg.content.empty?

          msg.tool_calls.each_value do |tool_call|
            content << format_tool_use_block(tool_call)
          end

          {
            role: 'assistant',
            content:
          }
        end

        def format_tool_result(msg)
          {
            role: 'user',
            content: msg.content.is_a?(RubyLLM::Content::Raw) ? msg.content.value : [format_tool_result_block(msg)]
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
          content = msg.content
          content = '(no output)' if content.nil? || (content.respond_to?(:empty?) && content.empty?)

          {
            type: 'tool_result',
            tool_use_id: msg.tool_call_id,
            content: Media.format_content(content)
          }
        end

        def function_for(tool)
          input_schema = tool.params_schema ||
                         RubyLLM::Tool::SchemaDefinition.from_parameters(tool.parameters)&.json_schema

          declaration = {
            name: tool.name,
            description: tool.description,
            input_schema: input_schema || default_input_schema
          }

          return declaration if tool.provider_params.empty?

          RubyLLM::Utils.deep_merge(declaration, tool.provider_params)
        end

        def extract_tool_calls(data)
          if json_delta?(data)
            # Use the content block index as the hash key so the accumulator
            # can route fragments to the correct tool call during parallel
            # streaming. Without this, all fragments go to @latest_tool_call_id
            # and parallel tool call arguments get concatenated together.
            block_index = data['index']
            key = block_index ? "block_idx_#{block_index}" : nil
            { key => ToolCall.new(id: nil, name: nil, arguments: data.dig('delta', 'partial_json')) }
          elsif data['type'] == 'content_block_start' && data.dig('content_block', 'type') == 'tool_use'
            block = data['content_block']
            build_tool_use_start(block, data['index'])
          else
            parse_tool_calls(data['content_block'])
          end
        end

        def build_tool_use_start(block, block_index)
          input = block['input']
          args = input.is_a?(Hash) && input.empty? ? +'' : (input || +'')
          tool_calls = { block['id'] => ToolCall.new(id: block['id'], name: block['name'], arguments: args) }
          if block_index
            tool_calls["register_idx_#{block_index}"] = ToolCall.new(
              id: block['id'], name: '_register_block_index', arguments: nil
            )
          end
          tool_calls
        end

        def parse_tool_calls(content_blocks)
          return nil if content_blocks.nil?

          content_blocks = [content_blocks] unless content_blocks.is_a?(Array)

          tool_calls = {}
          content_blocks.each do |block|
            next unless block && block['type'] == 'tool_use'

            tool_calls[block['id']] = ToolCall.new(
              id: block['id'],
              name: block['name'],
              arguments: block['input']
            )
          end

          tool_calls.empty? ? nil : tool_calls
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
