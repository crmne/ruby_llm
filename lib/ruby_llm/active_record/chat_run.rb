# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Connects a persisted chat's conversation loop to its record: usage
    # and progress land in the database, each cancellation checkpoint
    # renews the run claim and polls for a request from another process,
    # and losing the claim ends the run.
    class ChatRun < Chat::Run # :nodoc:
      def initialize(chat)
        super()
        @chat = chat
      end

      def record_usage(entry)
        @chat.persist_usage_entry(entry)
      end

      def record_progress(partial)
        @chat.persist_message_progress(partial)
      end

      def conversation_id
        @chat.id
      end

      def cancellation_requested?
        @chat.poll_run_cancellation == :cancelled
      end

      def interrupted_by?(error)
        @chat.run_claim_lost?(error)
      end
    end
  end
end
