# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Keeps approval decisions on tool call records, read outside the query
    # cache, so every process decides tool calls the same way. A call
    # approved with <tt>remember: true</tt> is recorded as +remembered+,
    # and later calls to the same tool in the chat run without asking.
    # A call saved while it requires approval is recorded as +pending+, so
    # pending approvals are read from the rows without building the chat's
    # tools.
    module ChatApprovals # :nodoc:
      private

      def persisted_pending_approvals
        pending = chat_tool_calls.where(approval: 'pending', result_id: nil)
        remembered = RubyLLM::ActiveRecord::ToolCall.uncached do
          chat_tool_calls.where(approval: 'remembered').distinct.pluck(*tool_identity)
        end
        remembered.reduce(pending) do |calls, identity|
          calls.where.not(id: pending.where(tool_identity.zip(Array(identity)).to_h).select(:id))
        end.order(:created_at, :id).skip_query_cache!
      end

      def tool_identity
        RubyLLM::ActiveRecord::ToolCall.column_names.include?('namespace') ? %i[namespace name] : %i[name]
      end

      def chat_tool_calls
        RubyLLM::ActiveRecord::ToolCall.where(
          message_type: messages_association.klass.polymorphic_name,
          message_id: messages_association.select(:id)
        )
      end

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

      def persisted_remembered_tool?(call)
        return false unless persisted? && row_supports_approval?

        RubyLLM::ActiveRecord::ToolCall.uncached do
          identity = tool_identity.to_h { |column| [column, call.public_send(column)] }
          chat_tool_calls.where(**identity, approval: 'remembered').exists?
        end
      end
    end
  end
end
