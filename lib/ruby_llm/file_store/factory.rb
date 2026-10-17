# frozen_string_literal: true

module RubyLLM
  class FileStore
    # Builds the stores RubyLLM ships, so attaching one needs no class
    # names. RubyLLM.file_store returns it.
    #
    #   chat.with_file_store(RubyLLM.file_store.directory("tmp/work"))
    #   chat.with_file_store(RubyLLM.file_store.memory)
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
