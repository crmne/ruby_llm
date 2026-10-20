# frozen_string_literal: true

require 'ruby_llm/active_record/payload_helpers'

module RubyLLM
  module ActiveRecord
    # RubyLLM's private persistence for provider tool calls.
    class ToolCall < Record # :nodoc:
      self.table_name = 'ruby_llm_tool_calls'

      include PayloadHelpers

      belongs_to :message, polymorphic: true
      belongs_to :result, polymorphic: true, optional: true

      validates :tool_call_id, :name, presence: true

      def to_llm
        RubyLLM::ToolCall.new(
          id: tool_call_id,
          provider_call_id: self[:provider_call_id],
          name: name,
          arguments: arguments || {},
          thought_signature: thought_signature,
          remote: self[:remote]
        )
      end

      # Returns whether a process is running this tool call: it has no
      # result yet and its claim has not expired.
      def running?
        (result_id.nil? && has_attribute?(:claimed_until) && claimed_until&.future?) || false
      end

      # Returns whether the call waits on a task or an MCP input request.
      def paused?
        has_attribute?(:mcp_state) && mcp_state.present?
      end

      def tool_error_message
        payload_error_message(arguments)
      end
    end
  end
end
