# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # The file store of a persisted chat, added by +acts_as_chat+ with
    # ChatMethods: the chat's files live in +ruby_llm_chat_files+, with
    # their content in Active Storage.
    module ChatFiles
      # Applies Chat#with_file_store and returns this record. Without a
      # +store+, the chat keeps its files in Active Storage, in
      # +ruby_llm_chat_files+ (see ActiveRecord::FileStore), for the
      # chat's owner, the record <tt>acts_as_chat owner:</tt> names: that
      # store writes files for the owner and sees only their files and the
      # files without an owner. Pass +nil+ to remove the store.
      #
      #   chat.with_file_store
      #   chat.with_file_store("tmp/chats/42")
      #   chat.with_file_store(:memory)
      #   chat.with_file_store(nil)
      #
      # :call-seq:
      #   with_file_store(store = active_storage_store, inline_limit: 10_000, tools: %i[read write edit])
      def with_file_store(store = RubyLLM::Chat::FileReferences::DEFAULT_STORE, **)
        store = FileStore.new(self) if store.equal?(RubyLLM::Chat::FileReferences::DEFAULT_STORE)
        to_llm.with_file_store(store, **)
        self
      end
    end
  end
end
