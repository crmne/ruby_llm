# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Keeps a message for the person about the last failed reply in the
    # chats table's +reply_error+ column, when it has one, so the chat's
    # page shows it however its broadcasts arrive. A failed run writes it,
    # and the next run clears it. A stop is not a failure.
    module ChatReplyError # :nodoc:
      MESSAGES = {
        failed: 'The reply failed. Send your message again.',
        too_long: 'This conversation is too long for the model. Start a new chat.'
      }.freeze

      private

      def clear_reply_error
        update_columns(reply_error: nil) if reply_error_column? && self[:reply_error]
      end

      def record_reply_error(error)
        return if error.is_a?(CancelledError) || !reply_error_column?

        key = error.is_a?(ContextLengthExceededError) ? :too_long : :failed
        update_columns(reply_error: I18n.t(key, scope: %i[ruby_llm reply_error], default: MESSAGES[key]))
      rescue StandardError => e
        RubyLLM.logger.warn("RubyLLM could not save the reply error: #{e.class}: #{e.message}")
      end

      def reply_error_column?
        persisted? && has_attribute?(:reply_error)
      end
    end
  end
end
