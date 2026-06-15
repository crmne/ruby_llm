# frozen_string_literal: true

require 'active_support/concern'

module RubyLLM
  module ActiveRecord
    # Methods mixed into batch models. A persisted batch mirrors RubyLLM::Batch:
    # it stores the provider's batch id and the chats it's processing, so a later
    # process can poll it and the answers land back in those conversations.
    module BatchMethods
      extend ActiveSupport::Concern

      included do
        before_create :submit
      end

      def chats=(chats)
        @chats = Array(chats)
        self.chat_ids = @chats.map(&:id)
      end

      def to_llm
        @to_llm ||= RubyLLM::Batch.new(
          provider: batch_provider,
          chats: batch_chats.map { |chat| chat&.to_llm },
          id: provider_batch_id,
          status: status,
          completed: completed
        )
      end

      # Caches the provider's status onto the record while polling, so a job can
      # find the unfinished ones.
      def complete?
        self.completed = to_llm.complete?
        self.status = to_llm.status
        save! if changed?
        completed
      end

      def messages
        to_llm.messages
      end

      def cancel
        to_llm.cancel
        self.completed = to_llm.complete?
        self.status = to_llm.status
        save! if changed?
        self
      end

      private

      # Submits as the record is created, so the row is born with its provider id.
      def submit
        result = RubyLLM::Batch.submit(@chats)
        self.provider_batch_id = result.id
        self.provider = @chats.first.provider
        self.status = result.status
      end

      def batch_provider
        RubyLLM::Provider.resolve!(provider).new(RubyLLM.config)
      end

      # In submission order, with a nil where a chat has since been deleted, so a
      # result's custom_id (its index) still lines up with the right chat.
      def batch_chats
        by_id = batch_chat_class.constantize.where(id: chat_ids).index_by(&:id)
        Array(chat_ids).map { |id| by_id[id] }
      end
    end
  end
end
