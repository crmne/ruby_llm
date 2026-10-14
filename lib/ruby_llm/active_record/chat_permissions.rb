# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Keeps approval decisions on tool call records, and a chat's
    # permissions mode and grants in its +permissions+ and
    # +permission_grants+ columns, all read outside the query cache, so
    # every process decides tool calls the same way. Chats without the
    # permission columns keep the mode and grants in memory.
    module ChatPermissions # :nodoc:
      private

      def record_tool_call_decision(tool_call, decision)
        id = tool_call.respond_to?(:tool_call_id) ? tool_call.tool_call_id : tool_call
        id = id.id if id.respond_to?(:id) && !id.is_a?(String)
        record = RubyLLM::ActiveRecord::ToolCall.uncached { find_tool_call(id) }
        raise ArgumentError, "Unknown tool call: #{id.inspect}" unless record

        decide_persisted_tool_call(record, decision)
        record
      end

      def persisted_tool_call_approval(tool_call)
        record = RubyLLM::ActiveRecord::ToolCall.uncached { find_tool_call(tool_call.id) }
        return unless record&.has_attribute?(:approval)

        case record.approval
        when 'approved' then true
        when 'denied' then false
        end
      end

      def install_permissions(chat)
        chat.with_permissions(self[:permissions]) if has_attribute?(:permissions) && self[:permissions].present?
        chat.permissions_checker = proc { persisted_permissions }
        chat.permission_recorder = proc { |additions| persist_permission_grants(additions) }
      end

      def persisted_permissions
        return unless permissions_persisted?

        mode, grants = self.class.uncached { chat_row.pick(:permissions, :permission_grants) }
        { mode:, grants: grants || {} }
      end

      def persist_permissions_mode(mode)
        return unless has_attribute?(:permissions)

        self[:permissions] = mode&.to_s
        return unless persisted?

        chat_row.update_all(permissions: self[:permissions])
        clear_attribute_change(:permissions)
      end

      def persist_permission_grants(additions)
        return unless permissions_persisted?

        self.class.transaction do
          current = self.class.uncached { chat_row.lock.pick(:permission_grants) }
          grants = RubyLLM::Chat::Permissions.merge_grants(current, additions)
          chat_row.update_all(permission_grants: grants)
          grants
        end
      end

      def permissions_persisted?
        persisted? && has_attribute?(:permissions) && has_attribute?(:permission_grants)
      end
    end
  end
end
