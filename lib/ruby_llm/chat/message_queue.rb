# frozen_string_literal: true

module RubyLLM
  class Chat
    # Holds a chat's queued messages in memory. Any thread may queue or
    # withdraw while the conversation loop takes them, and each message is
    # taken or withdrawn once. A message that fails to join, or that a
    # timeout stops, stays queued, with the ones taken after it, and those
    # that joined are already yielded.
    class MessageQueue # :nodoc:
      def initialize(messages = [], &add)
        @add = add
        @messages = messages.map { |message| message.requeue(self) }
        @lock = Mutex.new
      end

      def push(content:, attachments:, steer:, sender:)
        queued = QueuedMessage.new(content:, attachments:, steer:, sender:, queue: self)
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
        while (queued = taken.first)
          message = @add.call(queued)
          taken.shift
          yield message, queued
        end
      ensure
        @lock.synchronize { @messages.unshift(*taken) } if taken&.any?
      end
    end
  end
end
