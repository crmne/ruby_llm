# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Gives each RubyLLM::Chunk streamed from a persisted chat the message
    # record it streams into.
    #
    #   chat.ask("Tell me a story", &:broadcast)
    #
    module ChunkMethods
      BROADCASTING_OFF = 'Messages do not broadcast. Set config.broadcast_messages = true in the ' \
                         'RubyLLM initializer, or pass broadcasts: true to acts_as_message, with ' \
                         'turbo-rails and Action Cable loaded.' # :nodoc:

      # Returns a block that gives each chunk the record +message+ returns
      # before passing it to +block+, or +nil+ without a block.
      def self.streaming(block, &message) # :nodoc:
        return unless block

        ->(chunk) { block.call(attach(chunk, message.call)) }
      end

      # Gives +chunk+ the record +message+ it streams into. Returns +chunk+.
      def self.attach(chunk, message) # :nodoc:
        chunk.extend(ChunkMethods)
        chunk.message = message
        chunk
      end

      # Returns the persisted message record this chunk streams into.
      attr_accessor :message

      # Appends this chunk to its message on the chat's page. See
      # MessageBroadcasting#broadcast_chunk. Raises
      # RubyLLM::ConfigurationError when the message does not broadcast.
      def broadcast
        raise RubyLLM::ConfigurationError, BROADCASTING_OFF unless message.respond_to?(:broadcast_chunk)

        message.broadcast_chunk(self)
      end
    end
  end
end
