# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # A file in a persisted chat's FileStore, in RubyLLM's
    # +ruby_llm_chat_files+ table, with its content in Active Storage. It
    # keeps the text a converter made of the file, so each version is
    # converted once.
    #
    #   chat.ruby_llm_chat_files.pluck(:path) # => ["contract.pdf", "results/search-call_1.json"]
    #
    # Rows with an +owner+ are seen only through a store for that owner
    # (see ChatFiles#with_file_store); rows without one are seen by every
    # store of the chat.
    class ChatFile < Record
      self.table_name = 'ruby_llm_chat_files'

      belongs_to :chat, polymorphic: true
      belongs_to :owner, polymorphic: true, optional: true

      # Declares the content attachment when Active Storage is loaded.
      # Called by +acts_as_chat+, since Active Storage loads after
      # RubyLLM's records.
      def self.declare_attachments # :nodoc:
        return unless respond_to?(:has_one_attached) && !reflect_on_attachment(:file)

        has_one_attached :file
      end

      # Returns the file as a RubyLLM::StoredFile.
      def to_stored_file
        RubyLLM::StoredFile.new(path:, byte_size:, content_type:, digest:, updated_at:,
                                owner: (owner if owner_id))
      end
    end
  end
end
