# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # The file store of a persisted chat, added by +acts_as_chat+ with
    # ChatMethods: the chat's files live in +ruby_llm_chat_files+, with
    # their content in Active Storage.
    module ChatFiles
      # Applies Chat#with_file_store and returns this record. Without a
      # +store+, the chat keeps its files in Active Storage, in
      # +ruby_llm_chat_files+ (see ActiveRecord::FileStore), written for
      # +owner+ when given: that store sees only the owner's files and the
      # files without an owner. Pass +nil+ to remove the store.
      #
      #   chat.with_file_store
      #   chat.with_file_store(owner: Current.user)
      #   chat.with_file_store(RubyLLM.file_store.directory("tmp/chats/42"))
      #   chat.with_file_store(nil)
      #
      # :call-seq: with_file_store(store = active_storage_store, owner: nil, spill_to_file: 10_000)
      def with_file_store(store = RubyLLM::Chat::FileReferences::DEFAULT_STORE, owner: nil, **)
        if store.equal?(RubyLLM::Chat::FileReferences::DEFAULT_STORE)
          store = RubyLLM::ActiveRecord::FileStore.new(self, owner:)
        elsif owner
          raise ArgumentError, 'owner: applies to the Active Storage store; give your own store its owner instead'
        end
        to_llm.with_file_store(store, **)
        self
      end
    end
  end
end
