# frozen_string_literal: true

require 'ruby_llm/active_record/attachment_helpers'

module RubyLLM
  module ActiveRecord
    # Keeps a persisted chat's queued messages in +ruby_llm_queued_messages+,
    # so any process can queue one and the process running the chat takes
    # it. Taking or unqueuing deletes the row, and only the process whose
    # delete removes it goes on, so each message joins once or not at all.
    class ChatQueue # :nodoc:
      include AttachmentHelpers

      def initialize(chat)
        @chat = chat
      end

      def push(content:, attachments:, steer:, owner:)
        QueuedMessage.transaction do
          queued = rows.create!(content:, steer:, owner:)
          persist_content(queued, attachments) unless attachments.nil?
          queued
        end
      end

      def delete(queued)
        id = queued.respond_to?(:id) ? queued.id : queued
        record = read { rows.find_by(id:) }
        return unless record && QueuedMessage.where(id: record.id).delete_all == 1

        record.attachments.purge_later if attachments?(record)
        record
      end

      def to_a
        read { rows.to_a }
      end

      def none?(steering_only: false)
        !available? || read { !scope(steering_only).exists? }
      end

      def take(steering_only: false)
        return [] unless available?

        read { scope(steering_only).to_a }.filter_map { |queued| take_one(queued) }
      end

      private

      def take_one(queued)
        QueuedMessage.transaction do
          next unless QueuedMessage.where(id: queued.id).delete_all == 1

          blobs = queued.attachments.blobs.to_a if attachments?(queued)
          message = @chat.add_message(role: :user, content: queued.content, attachments: blobs)
          detach(queued) if blobs
          [message, queued]
        end
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
