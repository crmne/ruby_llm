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
        remove_abandoned_placeholder

        attrs = { role: :assistant, content: '' }
        @message = messages_association.create!(attrs)
        @last_message_id = @message.id
        @message
      end

      def blank_placeholder?
        return false unless @message&.persisted? && @message.content.blank?
        return false unless @message.role.to_s == 'assistant'
        return false if unfinished_record?(@message)
        return false if @message.respond_to?(:attachments) && @message.attachments.attached?

        !@message.ruby_llm_tool_calls.exists?
      end

      # A process killed before its reply arrived leaves its placeholder
      # last, and the run that takes over the chat's claim writes a reply
      # of its own, so it removes that one. A reply the model gave records
      # usage, even a blank one. The claim is renewed first, so a run that
      # lost it never removes the placeholder of the run that took over.
      def remove_abandoned_placeholder
        return unless @run_claim_token

        transaction do
          renew_run_claim(force: true)
          record = messages_association.order(:id).last
          record.destroy if to_llm.send(:placeholder?, record&.to_llm) && !record.ruby_llm_usages.exists?
        end
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
