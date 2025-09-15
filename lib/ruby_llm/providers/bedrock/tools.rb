# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Tools methods for the AWS Bedrock API implementation
      module Tools
        module_function

        def tool_for(tool)
          {
            toolSpec: {
              name: tool.name,
              description: tool.description,
              inputSchema: {
                json: {
                  type: 'object',
                  properties: tool.parameters.transform_values { |param| param_schema(param) },
                  required: tool.parameters.select { |_, p| p.required }.keys
                }
              }
            }
          }
        end

        def param_schema(param)
          {
            type: param.type,
            description: param.description
          }.compact
        end

        # Parse Bedrock converse toolUse blocks into a hash of ToolCall objects keyed by toolUseId
        def parse_tool_calls(tool_use_blocks)
          return {} unless tool_use_blocks&.any?

          tool_use_blocks.to_h do |block|
            tool_use = block['toolUse'] || {}
            tool_use_id = tool_use['toolUseId'] || tool_use['id']

            [
              tool_use_id,
              RubyLLM::ToolCall.new(
                id: tool_use_id,
                name: tool_use['name'],
                arguments: tool_use['input'] || {}
              )
            ]
          end
        end

        # Format a user message that contains one or more toolUse blocks
        # Expects role to already be converted to Bedrock's role string
        def format_tool_call(msg, role:)
          tool_calls = msg.tool_calls.values.compact

          if tool_calls.empty?
            RubyLLM.logger.warn 'Bedrock: tool_calls empty for tool call message'
            return nil
          end

          content_blocks = tool_calls.filter_map do |tc|
            next if tc.id.nil? || tc.id.empty?

            { 'toolUse' => { 'toolUseId' => tc.id, 'name' => tc.name, 'input' => tc.arguments } }
          end

          if content_blocks.empty?
            RubyLLM.logger.warn 'Bedrock: all tool_calls had missing ids; skipping tool call message'
            return nil
          end

          result = { role: role, content: content_blocks }

          RubyLLM.logger.debug "Formatted tool call: #{result}" if RubyLLM.config.log_stream_debug

          result
        end

        # Format a user message that returns tool results for prior toolUse calls
        # Expects role to already be converted to Bedrock's role string
        def format_tool_result(msg, role:)
          tool_call_id = msg.tool_call_id
          if tool_call_id.nil? || tool_call_id.empty?
            RubyLLM.logger.warn 'Bedrock: tool_call_id is null or empty for tool result message'

            return nil
          end

          result = {
            role: role,
            content: [
              {
                'toolResult' => {
                  'toolUseId' => tool_call_id,
                  'content' => [{ 'text' => msg.content }]
                }
              }
            ]
          }

          RubyLLM.logger.debug "Formatted tool result: #{result}" if RubyLLM.config.log_stream_debug

          result
        end

        def tool_result_only_message?(message)
          return false unless message && message[:content].is_a?(Array)

          message[:content].all? { |c| c['toolResult'] }
        end

        def validate_no_tool_use_and_result!(messages)
          index = messages.find_index { |message| invalid_tool_content?(message) }
          return unless index

          RubyLLM.logger.error "Bedrock validation error: Message #{index} contains both toolUse and toolResult"
          RubyLLM.logger.error "Message content: #{messages[index][:content]}"
          raise 'Bedrock validation error: Message cannot contain both toolUse and toolResult'
        end

        def invalid_tool_content?(message)
          return false unless message && message[:content]

          content = message[:content]
          has_tool_use = content.any? { |c| c['toolUse'] }
          has_tool_result = content.any? { |c| c['toolResult'] }
          has_tool_use && has_tool_result
        end

        def find_tool_uses(blocks)
          blocks.select { |c| c['toolUse'] }
        end
      end
    end
  end
end
