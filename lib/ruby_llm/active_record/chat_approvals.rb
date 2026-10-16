# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Keeps approval decisions on tool call records, read outside the query
    # cache, so every process decides tool calls the same way. A call
    # approved with <tt>remember: true</tt> is recorded as +remembered+,
    # and later calls to the same tool in the chat run without asking.
    module ChatApprovals # :nodoc:
      private

      def record_tool_call_decision(tool_call, decision)
        record = tool_call_record(tool_call)
        decide_persisted_tool_call(record, decision)
        record
      end

      def tool_call_record(tool_call)
        id = tool_call.respond_to?(:tool_call_id) ? tool_call.tool_call_id : tool_call
        id = id.id if id.respond_to?(:id) && !id.is_a?(String)
        record = RubyLLM::ActiveRecord::ToolCall.uncached { find_tool_call(id) }
        raise ArgumentError, "Unknown tool call: #{id.inspect}" unless record

        record
      end

      def persisted_tool_call_approval(tool_call)
        record = RubyLLM::ActiveRecord::ToolCall.uncached { find_tool_call(tool_call.id) }
        return unless record&.has_attribute?(:approval)

        case record.approval
        when 'approved', 'remembered' then true
        when 'denied' then false
        end
      end

      def persisted_remembered_tool?(name)
        return false unless persisted? && row_supports_approval?

        RubyLLM::ActiveRecord::ToolCall.uncached do
          RubyLLM::ActiveRecord::ToolCall.where(
            name:, approval: 'remembered',
            message_type: messages_association.klass.polymorphic_name,
            message_id: messages_association.select(:id)
          ).exists?
        end
      end
    end
  end
end
