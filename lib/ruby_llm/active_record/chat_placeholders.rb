# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Keeps the assistant record a run writes its answer into. An answer
    # the provider paused keeps its record, with the continuation that
    # resumes it, so a later run continues it instead of starting again.
    module ChatPlaceholders # :nodoc:
      def persist_message_progress(message) # :nodoc:
        return unless @message.has_attribute?(:continuation)

        transaction do
          @message.update!(message_attributes(message))
          link_usage_entries(message)
        end
      end

      private

      def persist_new_message
        unfinished = unfinished_message_record
        return @message = unfinished if unfinished

        @message.destroy if blank_placeholder?
        abandoned_placeholder_record&.destroy

        attrs = { role: :assistant, content: '' }
        @message = messages_association.create!(attrs)
        @last_message_id = @message.id
        @message
      end

      def blank_placeholder?
        blank_record?(@message)
      end

      def blank_record?(record)
        return false unless record&.persisted? && record.content.blank?
        return false unless record.role.to_s == 'assistant'
        return false if unfinished_record?(record)
        return false if record.respond_to?(:attachments) && record.attachments.attached?

        !record.ruby_llm_tool_calls.exists?
      end

      # A process killed before its reply arrived leaves its placeholder
      # last, and the run that takes over the chat's claim writes a reply
      # of its own, so it removes that one. A reply the model gave records
      # usage, even a blank one.
      def abandoned_placeholder_record
        return unless @run_claim_token

        record = messages_association.order(:id).last
        record if blank_record?(record) && !record.ruby_llm_usages.exists?
      end

      def unfinished_message_record
        record = messages_association.order(:id).last
        record if record&.role.to_s == 'assistant' && unfinished_record?(record)
      end

      def unfinished_record?(record)
        record.has_attribute?(:continuation) && record.continuation.present?
      end
    end
  end
end
