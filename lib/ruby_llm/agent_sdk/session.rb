# frozen_string_literal: true

require 'securerandom'

module RubyLLM
  module AgentSDK
    class Session
      DEFAULT_MAX_MESSAGES = 1000

      attr_reader :id, :created_at, :messages, :parent_id, :max_messages

      def initialize(id: nil, parent_id: nil, max_messages: DEFAULT_MAX_MESSAGES)
        @id = id || generate_id
        @parent_id = parent_id
        @created_at = Time.now
        @messages = []
        @max_messages = max_messages
      end

      def add_message(message)
        @messages << message
        @messages.shift if @messages.size > @max_messages
      end

      def last_message
        @messages.last
      end

      def forked?
        !@parent_id.nil?
      end

      def to_h
        {
          id: @id,
          created_at: @created_at.iso8601,
          message_count: @messages.size,
          forked: forked?,
          parent_id: @parent_id
        }
      end

      # Resume a previous session
      def self.resume(session_id, max_messages: DEFAULT_MAX_MESSAGES)
        new(id: session_id, max_messages: max_messages)
      end

      # Fork from an existing session (creates new session that continues from another)
      def fork
        self.class.new(parent_id: @id, max_messages: @max_messages).tap do |new_session|
          @messages.each { |msg| new_session.add_message(msg.dup) }
        end
      end

      private

      def generate_id
        SecureRandom.urlsafe_base64(32)
      end
    end
  end
end
