# frozen_string_literal: true

module RubyLLM
  class FileStore
    # Builds the stores RubyLLM ships, so attaching one needs no class
    # names. RubyLLM.file_store returns it.
    #
    #   chat.with_file_store(RubyLLM.file_store.memory)
    #   chat.with_file_store(RubyLLM.file_store.directory("tmp/work"))
    #   chat_record.with_file_store(RubyLLM.file_store.active_storage(chat_record, owner: user))
    #   config.file_converters["image/*"] = RubyLLM.file_store.converter.ocr
    #
    # For a store of your own, subclass FileStore.
    module Factory
      module_function

      # Returns a new FileStore::Memory, which keeps files for as long as
      # the chat lives.
      def memory
        Memory.new
      end

      # Returns a FileStore::Directory that keeps files in the folder at
      # +path+, creating it when missing.
      def directory(path)
        Directory.new(path)
      end

      # Returns the store a persisted chat keeps its files in: rows in
      # +ruby_llm_chat_files+, with their content in Active Storage,
      # written for +owner+ when given. +chat+ is an +acts_as_chat+ record.
      # RubyLLM's Rails integration defines it (see
      # ActiveRecord::FileStoreFactory); without it, this raises
      # ConfigurationError.
      #
      #   chat.with_file_store(RubyLLM.file_store.active_storage(chat, owner: Current.user))
      #
      # :call-seq: active_storage(chat, owner: nil)
      def active_storage(*, **)
        raise ConfigurationError, 'RubyLLM.file_store.active_storage needs RubyLLM\'s Rails integration. ' \
                                  'Outside Rails, use RubyLLM.file_store.memory or .directory(path).'
      end

      # Returns the converters RubyLLM ships, to register in
      # Configuration#file_converters. See Converters::Factory.
      #
      #   config.file_converters["image/*"] = RubyLLM.file_store.converter.ocr
      def converter
        Converters::Factory
      end
    end
  end
end
