# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # A user message queued on a persisted chat with ChatMethods#queue,
    # waiting in RubyLLM's +ruby_llm_queued_messages+ table until the
    # conversation loop takes it. Any process can queue one, and the
    # process that runs the chat takes it, so a request can add to a reply
    # a job is running. Its attachments move to the message it becomes.
    #
    #   chat.queued_messages.each { |queued| render queued }
    #   chat.unqueue(queued)
    #
    # It answers +content+, +attachments+, +owner+, and +steer?+, like
    # RubyLLM::QueuedMessage.
    class QueuedMessage < Record
      self.table_name = 'ruby_llm_queued_messages'

      belongs_to :chat, polymorphic: true
      belongs_to :owner, polymorphic: true, optional: true

      # Declares the attachments when Active Storage is loaded. Called by
      # +acts_as_chat+, since Active Storage loads after RubyLLM's records.
      def self.declare_attachments # :nodoc:
        return unless respond_to?(:has_many_attached) && !reflect_on_attachment(:attachments)

        has_many_attached :attachments
      end

      # Returns when the message was queued.
      def queued_at
        created_at
      end
    end
  end
end
