# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Responses
      # Approval requests and decisions for provider-managed tools.
      module Approvals
        module_function

        def render_tool_approval_response(tool_call, approved:)
          [{ type: 'mcp_approval_response', approval_request_id: tool_call.provider_call_id, approve: approved }]
        end

        def parse_tool_approvals(output, response: nil, finish_reason: nil)
          calls = output.filter_map do |item|
            next unless item['type'] == 'mcp_approval_request'

            arguments = item['arguments']
            arguments = parse_function_call_arguments(arguments, response:, finish_reason:) unless arguments.is_a?(Hash)
            ToolCall.new(provider_call_id: item.fetch('id'), name: item.fetch('name'), arguments:, remote: true)
          end
          ToolCall.index(calls, by: :provider_call_id)
        end

        def parse_pending_tool_calls(output, response: nil, finish_reason: nil)
          calls = (parse_function_calls(output, response:, finish_reason:) || {}).values +
                  parse_tool_approvals(output, response:, finish_reason:).values
          ToolCall.index(calls, by: :provider_call_id) unless calls.empty?
        end
      end
    end
  end
end
