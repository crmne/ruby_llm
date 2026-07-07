# frozen_string_literal: true

require 'active_support/concern'

module RubyLLM
  module ActiveRecord
    # Methods added to a batch model by +acts_as_batch+. A persisted batch
    # mirrors RubyLLM::Batch: it stores the provider's batch id and the chats
    # it is processing, so a later process can poll it and the answers land
    # back in those conversations.
    #
    # Creating the record submits the staged chats to the provider in the
    # same step:
    #
    #   chats = tickets.map do |ticket|
    #     Chat.create!(model: "claude-haiku-4-5").ask_later(ticket.body)
    #   end
    #
    #   batch = Batch.create!(chats: chats)
    #   BatchPollJob.perform_later(batch.id)
    #
    module BatchMethods
      extend ActiveSupport::Concern

      included do
        before_create :submit
      end

      # Sets the staged chats this batch will submit and records their ids
      # in +chat_ids+. Assign at creation time, as in
      # <tt>Batch.create!(chats: chats)</tt>; creating the record sends the
      # chats to the provider.
      def chats=(chats)
        @chats = Array(chats)
        self.chat_ids = @chats.map(&:id)
      end

      # Returns the chats this batch is processing, loaded from +chat_ids+
      # in submission order. Holds +nil+ where a chat has since been
      # deleted, so answers still line up with their chats by index.
      def chats
        by_id = batch_chat_class.constantize.where(id: chat_ids).index_by(&:id)
        Array(chat_ids).map { |id| by_id[id] }
      end

      # Returns the underlying RubyLLM::Batch for this record, rebuilt from
      # the stored provider, chats, batch id, and cached status. The result
      # is memoized.
      def to_llm
        @to_llm ||= RubyLLM::Batch.new(
          provider: batch_provider,
          chats: chats.map { |chat| chat&.to_llm },
          id: provider_batch_id,
          status: status,
          completed: completed
        )
      end

      # Polls the provider and caches the current status onto the record,
      # saving when it changed, so the batches still in flight are
      # <tt>Batch.where(completed: false)</tt>. Returns +self+.
      #
      #   Batch.where(completed: false).find_each(&:refresh)
      #
      def refresh
        to_llm.refresh
        cache_status
        self
      end

      # Returns whether the batch has finished processing, as of the last
      # #refresh. Reads the +completed+ column without contacting the
      # provider.
      #
      #   return unless batch.refresh.complete?
      #   batch.messages
      #
      def complete?
        completed
      end

      # Returns the answers in submission order, +nil+ where a request
      # failed, each also appended to its chat and persisted. Idempotent:
      # re-running after a retry never appends an answer twice.
      #
      #   batch.messages.each do |message|
      #     puts message.content
      #   end
      #
      def messages
        to_llm.messages
      end

      # Cancels the batch at the provider and caches the final status onto
      # the record. Requests already processed still return results.
      # Returns +self+.
      def cancel
        to_llm.cancel
        cache_status
        self
      end

      private

      def cache_status
        self.completed = to_llm.complete?
        self.status = to_llm.status
        save! if changed?
      end

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
    end
  end
end
