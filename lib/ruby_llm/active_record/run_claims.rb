# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Claims a persisted chat for the process that runs its conversation
    # loop, and each tool call for the process that answers it. Claims are
    # conditional updates, so no transaction stays open while a model or a
    # tool runs, and they expire after Configuration#max_run_time so another
    # process resumes the work of one that crashed.
    module RunClaims # :nodoc:
      class ClaimLost < StandardError; end # :nodoc:
      private_constant :ClaimLost

      private

      def exclusively(busy, &)
        return yield if @run_claim_token
        return busy.call if run_claims? && !run_claim_acquired?

        holding_run_claim(busy, &)
      end

      def holding_run_claim(busy)
        result = yield
        completed = true
        result
      rescue ClaimLost
        @message.destroy if blank_placeholder?
        resync_messages if @chat
        busy.call
      ensure
        release_run_claim(completed)
      end

      def run_claim_acquired?
        now = Time.current
        claim = { claim_token: SecureRandom.uuid, claimed_until: now + run_claim_duration }
        available = unclaimed(chat_row, now)
        unless available.where(claim_token: @synced_run_claim_token).update_all(claim) == 1
          return false unless available.update_all(claim) == 1

          stale = true
        end

        @run_claim_token = claim[:claim_token]
        @run_claimed_until = claim[:claimed_until]
        @run_claim_renewed_at = now
        resync_messages if stale && @chat
        true
      end

      def release_run_claim(completed)
        token = @run_claim_token
        return unless token

        @run_claim_token = nil
        chat_row.where(claim_token: token).update_all(claimed_until: nil)
        @synced_run_claim_token = completed ? token : nil # mutineer:disable-line boolean_literal -- no claim token is true either
      end

      def renew_run_claim(force: false)
        return unless @run_claim_token

        now = Time.current
        return unless force || now >= @run_claim_renewed_at + (run_claim_duration / 4.0)

        extend_run_claim([@run_claimed_until, now + run_claim_duration].max, now)
      end

      def extend_run_claim(claimed_until, now = Time.current)
        raise ClaimLost unless chat_row.where(claim_token: @run_claim_token).update_all(claimed_until:) == 1

        @run_claimed_until = claimed_until
        @run_claim_renewed_at = now
      end

      def running_elsewhere?
        return false unless run_claims?

        token, claimed_until = self.class.uncached { chat_row.pick(:claim_token, :claimed_until) }
        (claimed_until&.future? && token != @run_claim_token) || false
      end

      def work_arrived_during_run?
        return false if @run_claim_token || !run_claims?

        latest = messages_association.klass.uncached do
          messages_association.reorder(created_at: :desc, id: :desc).pick(:id)
        end
        resync_messages if latest != @last_message_id
        !to_llm.complete? && !to_llm.waiting?
      end

      def resync_messages
        messages_association.reset
        messages_association.klass.uncached { sync_messages }
      end

      def snapshot_run_claim
        @synced_run_claim_token = self.class.uncached { chat_row.pick(:claim_token) } if run_claims?
      end

      def claim_persisted_tool_calls(leases, executing:)
        return leases.keys.map(&:id) unless tool_call_claims?

        rows = RubyLLM::ActiveRecord::ToolCall.uncached { tool_call_rows(leases.keys.map(&:id)) }
        claimed = RubyLLM::ActiveRecord::ToolCall.transaction do
          ids = leases.filter_map do |tool_call, seconds|
            row = rows[tool_call.id]
            tool_call.id if row.nil? || tool_call_claimed?(tool_call.id, row, seconds, executing.include?(tool_call.id))
          end
          extend_run_claim_for_tool_calls
          ids
        end
        resync_messages if claimed.size < leases.size
        claimed
      end

      def tool_call_claimed?(tool_call_id, row, seconds, executing)
        now = Time.current.change(usec: 0)
        claimed_until = now + seconds.to_f.ceil
        scope = unclaimed(RubyLLM::ActiveRecord::ToolCall.where(id: row, result_id: nil), now)
        if executing && row_supports_approval?
          approval = RubyLLM::ActiveRecord::ToolCall.arel_table[:approval]
          scope = scope.where(approval.eq(nil).or(approval.not_eq('denied')))
        end
        return false unless scope.update_all(claimed_until:, updated_at: now) == 1

        tool_call_claims[tool_call_id] = [row, claimed_until]
        true
      end

      def extend_run_claim_for_tool_calls
        latest = tool_call_claims.values.map(&:last).max
        extend_run_claim([@run_claimed_until, latest].max) if @run_claim_token && latest
      end

      def release_persisted_tool_calls(tool_call_ids)
        tool_call_ids.each do |tool_call_id|
          row, claimed_until = tool_call_claims.delete(tool_call_id)
          next unless row

          RubyLLM::ActiveRecord::ToolCall.where(id: row, result_id: nil, claimed_until:)
                                         .update_all(claimed_until: nil)
        end
      end

      def tool_call_running_elsewhere?(tool_call)
        RubyLLM::ActiveRecord::ToolCall.uncached { find_tool_call(tool_call.id) }&.running? || false
      end

      def tool_result_recorded?(tool_call, message)
        attributes = { result_type: @message.class.polymorphic_name, result_id: @message.id, updated_at: Time.current }
        attributes[:mcp_result] = message.mcp_result&.dump if tool_call.has_attribute?(:mcp_result)
        attributes[:claimed_until] = nil if tool_call.has_attribute?(:claimed_until)
        tool_call_claims.delete(tool_call.tool_call_id)
        RubyLLM::ActiveRecord::ToolCall.where(id: tool_call.id, result_id: nil).update_all(attributes) == 1
      end

      def decide_persisted_tool_call(record, decision)
        return if record.approval == decision || decision_recorded?(record, decision)
        return unless decision == 'denied' && RubyLLM::ActiveRecord::ToolCall.uncached { record.reload }.running?

        raise ToolCallRunningError, "The #{record.name} tool call is already running"
      end

      def decision_recorded?(record, decision)
        now = Time.current
        scope = RubyLLM::ActiveRecord::ToolCall.where(id: record.id, result_id: nil)
        scope = unclaimed(scope, now) if record.has_attribute?(:claimed_until)
        scope.update_all(approval: decision, updated_at: now) == 1
      end

      def discard_superseded_message
        @message.destroy
        raise ClaimLost
      end

      def verify_run_claim
        renew_run_claim(force: true)
      rescue ClaimLost
        @message.destroy
        raise
      end

      def tool_call_rows(tool_call_ids)
        RubyLLM::ActiveRecord::ToolCall.where(
          tool_call_id: tool_call_ids,
          message_type: self.class.message_class.constantize.polymorphic_name,
          message_id: messages_association.select(:id)
        ).pluck(:tool_call_id, :id).to_h
      end

      def unclaimed(scope, now)
        claimed_until = scope.arel_table[:claimed_until]
        scope.where(claimed_until.eq(nil).or(claimed_until.lteq(now)))
      end

      def chat_row
        self.class.unscoped.where(self.class.primary_key => id)
      end

      def tool_call_claims
        @tool_call_claims ||= {}
      end

      def run_claims?
        persisted? && has_attribute?(:claim_token) && has_attribute?(:claimed_until) # mutineer:disable-line boolean_connector -- only an unsaved chat tells them apart, and it has no row to claim
      end

      def tool_call_claims?
        RubyLLM::ActiveRecord::ToolCall.column_names.include?('claimed_until')
      end

      def row_supports_approval?
        RubyLLM::ActiveRecord::ToolCall.column_names.include?('approval')
      end

      def run_claim_duration
        (context&.config || RubyLLM.config).max_run_time.to_f.ceil
      end
    end
  end
end
