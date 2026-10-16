# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Reads a cancellation request another process persisted on the chat
    # record, at most once per poll interval, and clears it once observed.
    module ChatCancellation # :nodoc:
      private

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
