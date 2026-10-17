# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # The file store of a persisted chat, added by +acts_as_chat+ with
    # ChatMethods: the chat's files live in +ruby_llm_chat_files+, with
    # their content in Active Storage.
    module ChatFiles
      # Applies Chat#with_files and returns this record. Without +store:+,
      # the chat keeps its files in Active Storage, in
      # +ruby_llm_chat_files+ (see #file_store).
      #
      #   chat.with_files
      #   chat.with_files(store: chat.file_store(owner: Current.user))
      #
      def with_files(enabled = true, **options)
        if enabled.is_a?(Hash)
          options = enabled.transform_keys(&:to_sym).merge(options)
          enabled = true
        end
        options = options.merge(store: file_store) if enabled == true && options[:store].nil?
        to_llm.with_files(enabled, **options)
        self
      end

      # Returns this chat's files as a FileStore kept in Active Storage. With
      # +owner:+, the store writes files for that owner and sees only theirs
      # and the files without an owner. See ActiveRecord::FileStore.
      def file_store(owner: nil)
        RubyLLM::ActiveRecord::FileStore.new(self, owner:)
      end
    end
  end
end
