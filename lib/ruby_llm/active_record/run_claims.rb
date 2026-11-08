# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Claims a persisted chat for the process that runs its conversation
    # loop, and each tool call for the process that answers it. Claims are
    # conditional updates, so no transaction stays open while a model or a
    # tool runs.
    #
    # A claim is a lease of CLAIM_LEASE seconds that a heartbeat thread
    # renews every CLAIM_RENEWAL seconds, or every quarter of a shorter
    # Configuration#max_run_time, so the work of a process that dies
    # is free again within a lease. Renewal stops at the claim's deadline:
    # Configuration#max_run_time after the run last made progress, or for
    # a tool call, its run time after it starts, so a run that hangs past
    # it counts as crashed. A call waiting for the calls before it in its
    # round keeps its claim as long as the chat's claim lasts. A run inside
    # a transaction can't renew from another connection, so its claims
    # last until their deadline instead.
    module RunClaims # :nodoc:
      class ClaimLost < StandardError; end # :nodoc:
      private_constant :ClaimLost

      # A tool call this process claimed: its row, when its claim ends, the
      # expiries written to the row, the seconds it may run, and whether it
      # started.
      ToolCallClaim = Struct.new(:row, :deadline, :written, :seconds, :started)
      private_constant :ToolCallClaim

      CLAIM_LEASE = 60
      CLAIM_RENEWAL = 15

      RUN_STATE = %i[
        @chat @message @last_message_id @last_cancellation_poll_at @unpersisted_instructions
        @usage_records_by_entry @run_claim_token @run_claim_deadline @run_claim_renewed_at
        @run_claim_lost_token @synced_run_claim_token @synced_usage_count @tool_call_claims
        @claim_heartbeat @claim_lock @tool_call_renewal_lock @lost_tool_calls @interrupted_tool_calls
      ].freeze
      private_constant :RUN_STATE

      # The chats whose run died holding its claim. Every run that ends
      # releases its claim, so a token whose lease expired is left only by
      # a process that died or shut down mid-run. A chat someone stopped
      # stays stopped. It skips the query cache, since a job polls it for
      # what other processes wrote.
      def self.interrupted(relation)
        chat = relation.klass
        return relation.none unless (%w[claim_token claimed_until] - chat.column_names).empty?

        died = relation.where.not(claim_token: nil).where(claimed_until: ..Time.current)
        died = died.where(cancelled: false) if chat.column_names.include?('cancelled')
        died.skip_query_cache!
      end

      def run_claim_lost?(error) # :nodoc:
        error.is_a?(ClaimLost)
      end

      def claim_persisted_tool_calls(leases, executing:) # :nodoc:
        return leases.keys.map(&:id) unless tool_call_claims?

        start_claim_heartbeat
        claimed = claim_tool_call_rows(leases, executing)
        resync_messages if claimed.size < leases.size
        claimed
      rescue StandardError
        claim_lock.synchronize { leases.each_key { |tool_call| tool_call_claims.delete(tool_call.id) } }
        stop_idle_claim_heartbeat
        raise
      end

      # A call that was running when its process shut down may have done
      # its work, such as a message it already sent, so it keeps its claim,
      # expired at once like the chat's: the expired claim is the only
      # record that it started. Every other call is released. A round that
      # stopped before it +finished+ writes its claims without yielding to a
      # fiber scheduler, as #unyielding explains, while one that finished
      # releases the calls that paused as usual.
      def release_persisted_tool_calls(tool_call_ids, stopped_by = nil, finished: false) # :nodoc:
        expired = Time.current.change(usec: 0) if shutting_down?(stopped_by)
        tool_call_ids.each do |tool_call_id|
          claim = claim_lock.synchronize { tool_call_claims.delete(tool_call_id) }
          next unless claim

          unyielding(!finished) do
            RubyLLM::ActiveRecord::ToolCall.where(id: claim.row, result_id: nil, claimed_until: claim.written)
                                           .update_all(claimed_until: (expired if claim.started))
          end
        end
      ensure
        stop_idle_claim_heartbeat
      end

      # Counts a claimed tool call's run time from now, when it starts, not
      # from when its round was claimed, so waiting for the calls before it
      # costs it nothing, and stretches the chat's claim to cover it. Until
      # then the call keeps its claim as long as the chat does. Both claims
      # are written before the call runs, so neither can lapse before the
      # heartbeat's next renewal, and the call doesn't run once another
      # process took either over.
      def persisted_tool_call_started(tool_call_id) # :nodoc:
        now = Time.current.change(usec: 0)
        claim = claim_lock.synchronize do
          started = tool_call_claims[tool_call_id]
          raise ClaimLost if started.nil? && lost_tool_calls.include?(tool_call_id)
          next unless started

          started.started = true
          started.deadline = now + started.seconds
          @run_claim_deadline = [@run_claim_deadline, started.deadline].max if @run_claim_token
          started
        end
        return unless claim

        write_run_claim(now) if @run_claim_token
        raise ClaimLost unless started_tool_call_claimed?(tool_call_id, claim, now)
      end

      # Whether this run claimed +tool_call_id+ from a process that had
      # started it and stopped, by a shutdown or a crash, before it saved
      # the result. Its claim is left expired, or lapses, while a call that
      # never started is released.
      def persisted_tool_call_interrupted?(tool_call_id) # :nodoc:
        claim_lock.synchronize { interrupted_tool_calls.include?(tool_call_id) }
      end

      def tool_call_running_elsewhere?(tool_call) # :nodoc:
        RubyLLM::ActiveRecord::ToolCall.uncached { find_tool_call(tool_call.id) }&.running? || false
      end

      private

      def claim_tool_call_rows(leases, executing)
        rows = RubyLLM::ActiveRecord::ToolCall.uncached { tool_call_rows(leases.keys.map(&:id)) }
        RubyLLM::ActiveRecord::ToolCall.transaction do
          ids = leases.filter_map do |tool_call, seconds|
            row = rows[tool_call.id]
            tool_call.id if row.nil? || tool_call_claimed?(tool_call.id, row, seconds, executing.include?(tool_call.id))
          end
          extend_run_claim_for_tool_calls
          ids
        end
      end

      def initialize_dup(*)
        super
        RUN_STATE.each { |name| instance_variable_set(name, nil) }
        %i[claim_token claimed_until].each { |name| self[name] = nil if has_attribute?(name) }
        self[:cancelled] = false if has_attribute?(:cancelled)
      end

      def exclusively(busy, &)
        return yield if @run_claim_token

        holding_run_claim(busy, &)
      end

      # A run stopped because its process is shutting down didn't end, so
      # it keeps its claim but expires it, and the chat counts as
      # interrupted at once.
      def holding_run_claim(busy)
        if run_claims?
          start_claim_heartbeat
          return busy.call unless run_claim_acquired?
        end

        settle_cancellation_request
        result = yield
        completed = true
        result
      rescue ClaimLost
        @message.destroy if blank_placeholder?
        resync_messages if @chat
        busy.call
      rescue SignalException, SystemExit => e
        stopped_by = e
        raise
      ensure
        unyielding(!completed) do
          stop_claim_heartbeat
        ensure
          shutting_down?(stopped_by) ? expire_run_claim : release_run_claim(completed)
        end
      end

      # Under a fiber scheduler, as in Async or Solid Queue's fiber workers,
      # a fiber whose thread is exiting or whose reactor is stopping is
      # cancelled, or never resumed, once it waits on a socket, a file or a
      # thread. So a run that +stopped+ before it finished ends its claims
      # without yielding to the scheduler, and one that finished yields as
      # usual.
      def unyielding(stopped, &)
        stopped ? Fiber.blocking(&) : yield
      end

      # Whether the process is shutting down: a thread killed at exit, or
      # +stopped_by+ a signal such as TERM or an exit. Interrupt doesn't
      # count: Ctrl-C in a console stops the run, and a job backend that
      # interrupts a job on shutdown, as Sidekiq does, runs it again.
      def shutting_down?(stopped_by)
        return true if Thread.current.status == 'aborting'

        (stopped_by.is_a?(SignalException) || stopped_by.is_a?(SystemExit)) && !stopped_by.is_a?(Interrupt)
      end

      def run_claim_acquired?
        now = Time.current
        deadline = now + run_claim_duration
        claim = { claim_token: SecureRandom.uuid, claimed_until: leased_until(deadline, now) }
        available = unclaimed(chat_row, now)
        unless available.where(claim_token: @synced_run_claim_token).update_all(claim) == 1
          return false unless available.update_all(claim) == 1

          stale = true
        end

        @run_claim_token = claim[:claim_token]
        @run_claim_deadline = deadline
        @run_claim_renewed_at = now
        resync_messages if @chat && (stale || run_finished_elsewhere?)
        true
      end

      # A released claim leaves no token behind, so what another process's
      # run wrote is the only sign of it. A failed attempt adds no message,
      # but each model call adds a usage row. Continuing an unfinished reply
      # keeps its id and may lose its usage row, so such a reply is always
      # read again: repeating it would bill the model twice.
      def run_finished_elsewhere?
        @chat.messages.last&.continuation || latest_message_id != @last_message_id ||
          usage_row_count != @synced_usage_count
      end

      def usage_row_count
        ruby_llm_usages.klass.uncached { ruby_llm_usages.count }
      end

      # Whole seconds, so a column that rounds fractions up still holds a
      # time that has passed.
      def expire_run_claim
        token = @run_claim_token
        @synced_usage_count = @synced_run_claim_token = @run_claim_token = nil
        chat_row.where(claim_token: token).update_all(claimed_until: Time.current.change(usec: 0)) if token
      end

      def release_run_claim(completed)
        token = @run_claim_token
        return unless token

        @synced_usage_count = @synced_run_claim_token = @run_claim_token = nil
        @synced_usage_count = usage_row_count if completed
      ensure
        free_chat_row(token) if token
      end

      def free_chat_row(token)
        cancellable = has_attribute?(:cancelled)
        released = { claim_token: nil, claimed_until: nil }
        released[:cancelled] = false if cancellable
        self[:cancelled] = false if chat_row.where(claim_token: token).update_all(released) == 1 && cancellable
      end

      def renew_run_claim(force: false)
        return unless @run_claim_token
        raise ClaimLost if @run_claim_lost_token == @run_claim_token

        now = Time.current
        claim_lock.synchronize { @run_claim_deadline = [@run_claim_deadline, now + run_claim_duration].max }
        write_run_claim(now) if force || now >= @run_claim_renewed_at + claim_renewal_interval
      end

      def write_run_claim(now = Time.current)
        claimed_until = leased_until(@run_claim_deadline, now)
        raise ClaimLost unless chat_claim_extended?(@run_claim_token, claimed_until)

        @run_claim_renewed_at = now
      end

      # Writes the chat's claim, moving its stored expiry forward and never
      # back: the heartbeat and a starting tool call write it from separate
      # threads, and the older of two writes can land last. Returns whether
      # the claim is still this run's.
      def chat_claim_extended?(token, claimed_until)
        chat_row.where(claim_token: token).update_all(
          ['claimed_until = CASE WHEN claimed_until IS NULL OR claimed_until < ? THEN ? ELSE claimed_until END',
           claimed_until, claimed_until]
        ) == 1
      end

      # Runs on the heartbeat's thread. A chat claim it finds taken is lost,
      # but only the run's own thread raises, at its next renewal.
      def renew_claim_leases
        now = Time.current
        renew_run_claim_lease(now)
        renew_tool_call_leases(now)
      end

      def renew_run_claim_lease(now)
        token = @run_claim_token
        deadline = @run_claim_deadline
        return unless token && deadline > now

        claimed_until = [now + CLAIM_LEASE, deadline].min
        if chat_claim_extended?(token, claimed_until)
          @run_claim_renewed_at = now
        else
          @run_claim_lost_token = token
        end
      end

      def renew_tool_call_leases(now)
        tool_call_renewal_lock.synchronize do
          renewals = claim_lock.synchronize do
            tool_call_claims.filter_map do |tool_call_id, claim|
              deadline = tool_call_deadline(claim)
              next unless deadline

              claimed_until = [now.change(usec: 0) + CLAIM_LEASE, deadline].min
              next if deadline <= now || claim.written.include?(claimed_until)

              [tool_call_id, claim.row, claim.written.dup, claim.written.push(claimed_until).last]
            end
          end
          renewals.each { |renewal| renew_tool_call_lease(*renewal) }
        end
      end

      # Writes a starting call's claim to its row, unless another process
      # took the row over, and returns whether this process still holds it.
      def started_tool_call_claimed?(tool_call_id, claim, now)
        tool_call_renewal_lock.synchronize do
          claimed_until = leased_until(claim.deadline, now)
          written = claim_lock.synchronize { claim.written.dup.tap { claim.written.push(claimed_until) } }
          renew_tool_call_lease(tool_call_id, claim.row, written, claimed_until)
          claim_lock.synchronize { tool_call_claims[tool_call_id].equal?(claim) }
        end
      end

      # A call that hasn't started yet, waiting for the calls before it in
      # its round, keeps its claim as long as the chat's claim lasts. Once
      # another process takes the chat over, this run won't start it, so
      # there is no deadline to renew to.
      def tool_call_deadline(claim)
        return claim.deadline if claim.started || !@run_claim_token
        return if @run_claim_lost_token == @run_claim_token

        [claim.deadline, @run_claim_deadline].max
      end

      def renew_tool_call_lease(tool_call_id, row, written, claimed_until)
        renewed = RubyLLM::ActiveRecord::ToolCall.where(id: row, result_id: nil, claimed_until: written)
                                                 .update_all(claimed_until:) == 1
        claim_lock.synchronize do
          claim = tool_call_claims[tool_call_id]
          next unless claim&.row == row
          next claim.written = [claimed_until] if renewed

          tool_call_claims.delete(tool_call_id)
          lost_tool_calls << tool_call_id
        end
      end

      def start_claim_heartbeat
        return if @claim_heartbeat || claims_in_transaction?

        claim_lock
        @claim_heartbeat = ClaimHeartbeat.new([self.class, RubyLLM::ActiveRecord::ToolCall], claim_renewal_interval) do
          renew_claim_leases
        end
      end

      def stop_idle_claim_heartbeat
        stop_claim_heartbeat unless @run_claim_token || claim_lock.synchronize { tool_call_claims.any? }
      end

      def stop_claim_heartbeat
        heartbeat = @claim_heartbeat
        @claim_heartbeat = nil
        heartbeat&.stop
      end

      def claims_in_transaction?
        self.class.connection_pool.with_connection(&:transaction_open?)
      end

      def leased_until(deadline, now)
        @claim_heartbeat ? [now + CLAIM_LEASE, deadline].min : deadline
      end

      # A max_run_time shorter than the lease is the claim's whole life, so
      # a renewal has to land within it.
      def claim_renewal_interval
        [CLAIM_RENEWAL, [CLAIM_LEASE, run_claim_duration].min / 4.0].min
      end

      def running_elsewhere?
        return false unless run_claims?

        token, claimed_until = self.class.uncached { chat_row.pick(:claim_token, :claimed_until) }
        (claimed_until&.future? && token != @run_claim_token) || false
      end

      def work_arrived_during_run?
        return false if @run_claim_token || !run_claims?

        resync_messages if latest_message_id != @last_message_id
        !to_llm.complete? && !to_llm.waiting?
      end

      def latest_message_id
        messages_association.klass.uncached do
          messages_association.reorder(created_at: :desc, id: :desc).pick(:id)
        end
      end

      def resync_messages
        messages_association.reset
        reload_usages
        messages_association.klass.uncached { sync_messages }
      end

      def reload_usages
        ruby_llm_usages.reset
        ruby_llm_usages.klass.uncached { ruby_llm_usages.load }
      end

      def snapshot_run_claim
        return unless run_claims?

        # Counting first means a run that starts after the token is read
        # still changes the count this process compares against.
        @synced_usage_count = usage_row_count
        @synced_run_claim_token = self.class.uncached { chat_row.pick(:claim_token) }
      end

      # Tool call rows carry no token, so this process recognizes its claim
      # on a row by the whole-second expiries it wrote there.
      def tool_call_claimed?(tool_call_id, row, seconds, executing)
        now = Time.current.change(usec: 0)
        seconds = seconds.to_f.ceil
        deadline = now + seconds
        claimed_until = leased_until(deadline, now)
        scope = unclaimed(RubyLLM::ActiveRecord::ToolCall.where(id: row, result_id: nil), now)
        if executing && row_supports_approval?
          approval = RubyLLM::ActiveRecord::ToolCall.arel_table[:approval]
          scope = scope.where(approval.eq(nil).or(approval.not_eq('denied')))
        end
        claimed, expired = claim_tool_call_row(scope, { claimed_until:, updated_at: now })
        return false unless claimed

        claim = ToolCallClaim.new(row, deadline, [claimed_until], seconds, false)
        claim_lock.synchronize do
          lost_tool_calls.delete(tool_call_id)
          interrupted_tool_calls.delete(tool_call_id)
          interrupted_tool_calls << tool_call_id if expired && executing
          tool_call_claims[tool_call_id] = claim
        end
        true
      end

      # A released call has no expiry, while a call that started keeps its
      # expired claim when its process shuts down, or lets it lapse when the
      # process dies. Returns whether the claim was written, and whether it
      # took over an expired one.
      def claim_tool_call_row(scope, written)
        return [true, false] if scope.where(claimed_until: nil).update_all(written) == 1

        [scope.where.not(claimed_until: nil).update_all(written) == 1, true]
      end

      def extend_run_claim_for_tool_calls
        extended = claim_lock.synchronize do
          latest = tool_call_claims.values.map(&:deadline).max
          @run_claim_deadline = [@run_claim_deadline, latest].max if @run_claim_token && latest
        end
        write_run_claim if extended
      end

      def tool_result_recorded?(tool_call, message)
        attributes = { result_type: @message.class.polymorphic_name, result_id: @message.id, updated_at: Time.current }
        attributes[:mcp_result] = message.mcp_result&.dump if tool_call.has_attribute?(:mcp_result)
        attributes[:claimed_until] = nil if tool_call.has_attribute?(:claimed_until)
        claim_lock.synchronize do
          tool_call_claims.delete(tool_call.tool_call_id)
          interrupted_tool_calls.delete(tool_call.tool_call_id)
        end
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
        transaction do
          forget_stale_cancellation
          scope.update_all(approval: decision, updated_at: now) == 1 || raise(::ActiveRecord::Rollback)
        end
      end

      def discard_superseded_message
        @message.destroy
        raise ClaimLost
      end

      # Renewing inside the transaction holds the chat row until the result
      # commits, so no other process can take the chat over in between.
      def fenced_by_run_claim(&)
        transaction do
          renew_run_claim(force: true)
          yield
        end
      rescue ClaimLost
        @message.destroy
        raise
      end

      def tool_call_rows(tool_call_ids)
        RubyLLM::ActiveRecord::ToolCall.where(
          tool_call_id: tool_call_ids,
          message_type: messages_association.klass.polymorphic_name,
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

      # Calls whose claim the heartbeat found taken, so their start fails
      # rather than taking them for calls that were never claimed.
      def lost_tool_calls
        @lost_tool_calls ||= Set.new
      end

      def interrupted_tool_calls
        @interrupted_tool_calls ||= Set.new
      end

      def claim_lock
        @claim_lock ||= Mutex.new
      end

      # Keeps the heartbeat and a starting call from writing a tool call's
      # row at once, when one write would find the other's expiry there and
      # take the claim for lost.
      def tool_call_renewal_lock
        claim_lock.synchronize { @tool_call_renewal_lock ||= Mutex.new }
      end

      def run_claims?
        persisted? && has_attribute?(:claim_token) && has_attribute?(:claimed_until)
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
