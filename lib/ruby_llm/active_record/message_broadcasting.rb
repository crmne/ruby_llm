# frozen_string_literal: true

require 'active_support/concern'

module RubyLLM
  module ActiveRecord
    # Shows a chat's messages live with Turbo. An empty assistant reply is
    # appended when it is created, so its chunks have a place to land, and
    # each chunk is appended as a numbered span that the chat UI's Stimulus
    # controller puts back in order. A saved message replaces itself, a
    # destroyed one is removed, and every change refreshes the chat page.
    # Broadcasts go to the chat record's stream:
    #
    #   <%= turbo_stream_from @chat %>
    #
    module MessageBroadcasting
      extend ActiveSupport::Concern

      # Returns whether Turbo broadcasting can run: turbo-rails and Action
      # Cable are loaded.
      def self.available?
        defined?(::Turbo::Broadcastable) && defined?(::ActionCable) ? true : false
      end

      included do
        after_create_commit -> { broadcast_append_to chat_association }, if: :streaming_placeholder?
        after_update_commit -> { broadcast_replace_to chat_association }
        after_destroy_commit -> { broadcast_remove_to chat_association }
        after_commit -> { broadcast_refresh_to chat_association }
      end

      # Appends the content of +chunk+, a RubyLLM::Chunk streamed into this
      # message, to the message's <tt><dom_id>_stream</tt> element as
      # <tt><span data-seq="index"></tt>, escaped. Each span names the
      # index of the span before it in <tt>data-after</tt>, so the page can
      # order them. Returns +nil+ for a chunk without content.
      #
      #   chat.ask("Tell me a story") { |chunk| chunk.message.broadcast_chunk(chunk) }
      #
      def broadcast_chunk(chunk)
        return if chunk.content.to_s.empty?

        after = @last_broadcast_chunk_index
        @last_broadcast_chunk_index = chunk.index
        broadcast_append_to chat_association,
                            target: "#{ActionView::RecordIdentifier.dom_id(self)}_stream",
                            content: chunk_span(chunk, after)
      end

      private

      def streaming_placeholder?
        role.to_s == 'assistant' && content.blank?
      end

      def chunk_span(chunk, after)
        after_attribute = %( data-after="#{after}") if after
        %(<span data-seq="#{chunk.index}"#{after_attribute}>#{ERB::Util.html_escape(chunk.content)}</span>)
      end
    end
  end
end
