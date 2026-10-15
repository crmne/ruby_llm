# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Gives each RubyLLM::Chunk streamed from a persisted chat the message
    # record it streams into.
    #
    #   chat.ask("Tell me a story", &:broadcast)
    #
    module ChunkMethods
      # Returns a block that gives each chunk the record +message+ returns
      # before passing it to +block+, or +nil+ without a block.
      def self.streaming(block, &message) # :nodoc:
        return unless block

        lambda do |chunk|
          chunk.extend(ChunkMethods)
          chunk.message = message.call
          block.call(chunk)
        end
      end

      # Returns the persisted message record this chunk streams into.
      attr_accessor :message

      # Appends this chunk to its message on the chat's page. See
      # MessageBroadcasting#broadcast_chunk.
      def broadcast
        message.broadcast_chunk(self)
      end
    end
  end
end
