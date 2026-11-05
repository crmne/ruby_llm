# frozen_string_literal: true

require 'ruby_llm/active_record/attachment_helpers'

module RubyLLM
  module ActiveRecord
    # Keeps a persisted chat's queued messages in +ruby_llm_queued_messages+,
    # so any process can queue one and the process running the chat takes
    # it. Taking or withdrawing deletes the row, and only the process whose
    # delete removes it goes on, so each message joins once or not at all.
    # Joining runs Chat#around_join inside the transaction that deletes the
    # row, so a callback that raises puts the row back.
    class ChatQueue # :nodoc:
      include AttachmentHelpers

      def initialize(chat)
        @chat = chat
      end

      def push(content:, attachments:, steer:, sender:)
        QueuedMessage.transaction do
          queued = rows.create!(content:, steer:, sender:)
          persist_content(queued, attachments) unless attachments.nil?
          queued
        end
      end

      def delete(queued)
        id = queued.respond_to?(:id) ? queued.id : queued
        record = read { rows.find_by(id:) }
        record if record&.withdraw
      end

      def to_a
        read { rows.to_a }
      end

      def none?(steering_only: false)
        !available? || read { !scope(steering_only).exists? }
      end

      def take(steering_only: false)
        return unless available?

        read { scope(steering_only).to_a }.each do |queued|
          taken = take_one(queued)
          yield taken.first, queued if taken
        end
      end

      private

      def take_one(queued)
        taken = nil
        QueuedMessage.transaction do
          next unless QueuedMessage.where(id: queued.id).delete_all == 1

          taken = [@chat.to_llm.run_around_join(queued) { |**attributes| join(queued, attributes) }]
        rescue StandardError
          @chat.messages_association.reset
          raise
        end
        queued.attachments.purge_later if taken == [nil] && attachments?(queued)
        taken
      end

      def join(queued, attributes)
        blobs = queued.attachments.blobs.to_a if attachments?(queued)
        message = @chat.persist_message({ role: :user, content: queued.content, attachments: blobs }, attributes)
        detach(queued) if blobs
        message
      end

      def detach(queued)
        ActiveStorage::Attachment.where(record_type: QueuedMessage.polymorphic_name, record_id: queued.id,
                                        name: 'attachments').delete_all
      end

      def scope(steering_only)
        steering_only ? rows.where(steer: true) : rows
      end

      def rows
        @chat.ruby_llm_queued_messages.scope
      end

      def read(&)
        QueuedMessage.uncached(&)
      end

      def attachments?(queued)
        queued.respond_to?(:attachments) && queued.attachments.attached?
      end

      def available?
        @chat.persisted? && QueuedMessage.table_exists?
      end
    end
  end
end
