# frozen_string_literal: true

module RubyLLM
  class Chat
    # Holds a chat's queued messages in memory. Any thread may queue or
    # unqueue while the conversation loop takes them, and each message is
    # taken or unqueued once. A message that fails to join stays queued,
    # with the ones taken after it.
    class MessageQueue # :nodoc:
      def initialize(messages = [], &add)
        @add = add
        @messages = messages.dup
        @lock = Mutex.new
      end

      def push(content:, attachments:, steer:, owner:)
        queued = QueuedMessage.new(content:, attachments:, steer:, owner:)
        @lock.synchronize { @messages << queued }
        queued
      end

      def delete(queued)
        id = queued.respond_to?(:id) ? queued.id : queued
        @lock.synchronize do
          index = @messages.index { |message| message.id == id }
          @messages.delete_at(index) if index
        end
      end

      def to_a
        @lock.synchronize { @messages.dup }
      end

      def none?(steering_only: false)
        @lock.synchronize { @messages.none? { |message| message.steer? || !steering_only } }
      end

      def take(steering_only: false)
        taken = @lock.synchronize do
          ready, @messages = @messages.partition { |message| message.steer? || !steering_only }
          ready
        end
        taken.each_with_index.map do |queued, index|
          [@add.call(queued), queued]
        rescue StandardError
          @lock.synchronize { @messages.unshift(*taken.drop(index)) }
          raise
        end
      end
    end
  end
end
