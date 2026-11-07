# frozen_string_literal: true

module RubyLLM
  class Chat
    # What the conversation loop tells the world around it, and asks of it.
    # A plain chat reports usage through +usage.ruby_llm+ and has nothing
    # else to consult. The Rails integration swaps in ActiveRecord::ChatRun,
    # which reaches the record that owns the run. A copy of the chat shares
    # it.
    class Run # :nodoc:
      def record_usage(entry)
        Accounting::Usage.record(entry)
      end

      def record_progress(_partial); end

      def conversation_id; end

      def owner; end

      def cancellation_requested?
        false
      end

      def interrupted_by?(_error)
        false
      end
    end
  end
end
