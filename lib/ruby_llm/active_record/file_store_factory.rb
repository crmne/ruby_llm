# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Gives RubyLLM.file_store its +active_storage+ store once the Rails
    # integration loads, so the three stores RubyLLM ships read alike:
    #
    #   chat.with_file_store(RubyLLM.file_store.memory)
    #   chat.with_file_store(RubyLLM.file_store.directory("tmp/work"))
    #   chat.with_file_store(RubyLLM.file_store.active_storage(chat, owner: Current.user))
    module FileStoreFactory
      # Returns the FileStore of +chat+, an +acts_as_chat+ record: its files
      # are rows in +ruby_llm_chat_files+, with their content in Active
      # Storage, written for +owner+ when given. It is the store
      # ChatFiles#with_file_store uses when given none.
      #
      # Raises ArgumentError when +chat+ is not an +acts_as_chat+ record,
      # and ConfigurationError when Active Storage is not loaded.
      def active_storage(chat, owner: nil)
        unless chat.is_a?(ChatFiles)
          raise ArgumentError, "RubyLLM.file_store.active_storage needs an acts_as_chat record, not #{chat.class}"
        end
        unless ChatFile.respond_to?(:reflect_on_attachment) && ChatFile.reflect_on_attachment(:file)
          raise ConfigurationError, 'RubyLLM.file_store.active_storage needs Active Storage. ' \
                                    'Load it with require "active_storage/engine" in config/application.rb, ' \
                                    'then run bin/rails active_storage:install and bin/rails db:migrate.'
        end

        FileStore.new(chat, owner:)
      end
    end
  end
end

RubyLLM::FileStore::Factory.singleton_class.prepend(RubyLLM::ActiveRecord::FileStoreFactory)
