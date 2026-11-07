# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Reads a cancellation request another process persisted on the chat
    # record, at most once per poll interval, and clears it once observed.
    # A request is for the run holding the chat, or for the run about to
    # answer what waits. New work recorded while no run holds the chat, and
    # a run that finds nothing waiting, clear a request that is left over.
    # A request also reaches the runs of the chat's subagents, which stop
    # the call that runs them.
    module ChatCancellation # :nodoc:
      def poll_run_cancellation # :nodoc:
        renew_run_claim
        consume_persisted_cancellation_request
      end

      # Requests cancellation of the run that holds the chat, when one does,
      # and of the runs of its subagents.
      def cancel_run # :nodoc:
        cancel_claimed_run if run_claims?
        subagent_chats.each(&:cancel_run)
      end

      def forget_stale_cancellation # :nodoc:
        return if @run_claim_token || !run_claims? || !has_attribute?(:cancelled)

        requested = unclaimed(chat_row.where(cancelled: true), Time.current)
        remember_cancellation(false) if requested.update_all(cancelled: false) == 1
      end

      private

      def request_cancellation
        return request_run_cancellation if run_claims?

        persisted? ? update_column(:cancelled, true) : self[:cancelled] = true
        @chat&.cancel
      end

      def request_run_cancellation
        if cancel_claimed_run == 1
          remember_cancellation(true)
          @chat&.cancel if @run_claim_token
        elsif !nothing_to_stop?
          update_column(:cancelled, true)
        end
        subagent_chats.each(&:cancel_run)
      end

      # The conditional update can't land after the run's release, which
      # clears the request, so it can't outlive the run it was meant for.
      def cancel_claimed_run
        claimed_until = chat_row.arel_table[:claimed_until]
        chat_row.where(claimed_until.gt(Time.current)).update_all(cancelled: true)
      end

      def nothing_to_stop?
        return false unless ChatQueue.new(self).none?

        messages_association.klass.uncached do
          latest = messages_association.where.not(role: :system).reorder(created_at: :desc, id: :desc).first
          latest.nil? || finished_reply?(latest)
        end
      end

      def finished_reply?(message)
        message.role.to_s == 'assistant' && message.content.present? &&
          !unfinished_record?(message) && !message.tool_call?
      end

      def settle_cancellation_request
        return unless @run_claim_token && has_attribute?(:cancelled)

        remember_cancellation(self.class.uncached { chat_row.pick(:cancelled) })
        clear_cancellation_request if self[:cancelled] && to_llm.complete? && ChatQueue.new(self).none?
      end

      def remember_cancellation(requested)
        self[:cancelled] = requested
        clear_attribute_changes([:cancelled])
      end

      def consume_persisted_cancellation_request
        if self[:cancelled]
          clear_cancellation_request
          return :cancelled
        end
        return unless persisted?
        return unless cancellation_poll_due?
        return unless persisted_cancellation_request?

        clear_cancellation_request
        :cancelled
      end

      # Jobs and requests run with the query cache on, which would replay the
      # first poll's answer for the rest of the run.
      def persisted_cancellation_request?
        self.class.uncached do
          self.class.unscoped.where(self.class.primary_key => id).pick(:cancelled)
        end
      end

      def clear_cancellation_request
        self[:cancelled] = false
        self.class.unscoped.where(self.class.primary_key => id).update_all(cancelled: false) if persisted?
      end

      def cancellation_poll_due?
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        interval = ChatMethods::CANCELLATION_POLL_INTERVAL
        return false if @last_cancellation_poll_at && now - @last_cancellation_poll_at < interval

        @last_cancellation_poll_at = now
        true
      end
    end
  end
end
