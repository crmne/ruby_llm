# frozen_string_literal: true

require 'stringio'

module RubyLLM
  module ActiveRecord
    # Keeps a persisted chat's files in +ruby_llm_chat_files+, with their
    # content in Active Storage, so they live on whatever service Active
    # Storage uses: a disk now, a bucket later. A persisted chat uses one
    # when ChatFiles#with_file_store is given no store.
    #
    #   chat.with_file_store
    #   chat.file_store.list
    #
    # With +owner:+, the store writes files for that owner and sees only
    # their files and the files without an owner, so in a chat several
    # people share, one person's tool results stay theirs:
    #
    #   chat.with_file_store(owner: Current.user)
    #
    # What the model last read of a file is kept in the row's
    # +read_digest+ column, so it holds across processes, and #with_lock
    # locks the chat's row. Converted text is kept in the row's +text+
    # column. Encrypt it, like
    # anything else the model reads, with
    # <tt>RubyLLM::ActiveRecord::ChatFile.encrypts :text</tt>.
    class FileStore < RubyLLM::FileStore
      # The chat record the files belong to.
      attr_reader :chat

      # The owner the store writes files for, or +nil+.
      attr_reader :owner

      # Creates a store for the files of the +chat+ record, writing them for
      # +owner+ when given.
      #
      # Raises ArgumentError when +chat+ is not an +acts_as_chat+ record,
      # and ConfigurationError when Active Storage is not loaded.
      def initialize(chat, owner: nil)
        unless chat.is_a?(ChatFiles)
          raise ArgumentError, "#{self.class} needs an acts_as_chat record, not #{chat.class}"
        end
        unless ChatFile.respond_to?(:reflect_on_attachment) && ChatFile.reflect_on_attachment(:file)
          raise ConfigurationError, "#{self.class} needs Active Storage. " \
                                    'Load it with require "active_storage/engine" in config/application.rb, ' \
                                    'then run bin/rails active_storage:install and bin/rails db:migrate.'
        end

        super()
        @chat = chat
        @owner = owner
      end

      # Returns the files inside the folder +prefix+, or every file.
      def list(prefix = nil)
        scope = prefix.present? ? inside(path(prefix)) : visible
        preferred(scope.includes(:owner).order(:path, :id).to_a).map(&:to_stored_file)
      end

      # Returns the StoredFile at +path+, or +nil+.
      def [](path)
        row(path)&.to_stored_file
      end

      # Returns the content of the file at +path+.
      def read(path)
        record = row(path) || raise(FileNotFoundError, "No file at #{path(path)}")
        record.file.download.b
      end

      # Writes +content+ to +path+ and returns its StoredFile.
      def write(path, content, content_type: nil)
        content = RubyLLM::FileStore.bytes(content)
        path = path(path)
        type = content_type || RubyLLM::FileStore.content_type_for(path, content)
        save(path, content.bytesize, type, RubyLLM::FileStore.digest(content)) do |record|
          record.file.attach(io: StringIO.new(content), filename: File.basename(path), content_type: type)
        end
      end

      # Deletes the file at +path+ and returns its StoredFile, or +nil+. A
      # store with an owner deletes only that owner's files.
      def delete(path)
        path = path(path)
        record = owned.find_by(path:)
        refuse_folder(path) if record.nil? && rows_in_folder(path).any? { |row| row.path != path }
        record&.destroy
        record&.to_stored_file
      end

      # Deletes everything inside the folder +path+ and returns the deleted
      # StoredFile objects. A store with an owner deletes only that
      # owner's files.
      def delete_folder(path)
        path = path(path)
        refuse_file(path) if row(path)

        ChatFile.transaction do
          rows_in_folder(path, owned).each(&:destroy).map(&:to_stored_file)
        end
      end

      # Returns the digest of what the model last read at +path+, from the
      # file's row, or +nil+.
      def read_digest(path)
        return super unless read_digests?

        row(path)&.read_digest
      end

      # Keeps +digest+ as what the model read at +path+, in the file's row.
      def record_read(path, digest)
        return super unless read_digests?

        row(path)&.update_columns(read_digest: digest)
      end

      # Runs the block in a transaction that locks the chat's row, past
      # the query cache, so other processes wait for it.
      def with_lock
        super do
          ChatFile.uncached do
            ChatFile.transaction do
              lock_chat
              yield
            end
          end
        end
      end

      # Returns the text kept for +file+, or +nil+.
      def cached_text(file)
        record = row(file.path)
        record.text if record&.digest == file.digest && record.has_attribute?(:text)
      end

      # Keeps +text+ for +file+ in its row.
      def cache_text(file, text)
        record = row(file.path)
        record.update_columns(text:) if record&.digest == file.digest && record.has_attribute?(:text)
      end

      # Keeps an attachment from Active Storage by its blob, without
      # copying it: the file and the message share the blob.
      def store_attachment(attachment) # :nodoc:
        blob = blob_of(attachment)
        return super unless blob

        existing = visible.joins(:file_blob).find_by(active_storage_blobs: { id: blob.id })
        existing ? existing.to_stored_file : super
      end

      private

      def read_digests?
        ChatFile.column_names.include?('read_digest')
      end

      def rows_in_folder(folder, scope = visible)
        inside(folder, scope).includes(:owner).order(:path, :id)
                             .select { |row| RubyLLM::FileStore.inside?(row.path, folder) }
      end

      def write_attachment(path, attachment, content)
        blob = blob_of(attachment)
        return super unless blob

        save(path, blob.byte_size, attachment.mime_type, RubyLLM::FileStore.digest(content)) do |record|
          record.file.attach(blob)
        end
      end

      def save(path, byte_size, content_type, digest)
        ChatFile.transaction do
          lock_chat
          record = owned.lock.find_or_initialize_by(path:)
          record.assign_attributes(byte_size:, content_type:, digest:)
          record.text = nil if record.has_attribute?(:text)
          yield record
          record.save!
          record.to_stored_file
        end
      end

      # SQLite has no row locks, and a deferred transaction that reads
      # first fails when it later writes beside another writer, so it takes
      # the write lock at once with a no-op update.
      def lock_chat
        key = @chat.class.primary_key
        scope = @chat.class.unscoped.where(key => @chat.id)
        return scope.lock.pick(key) unless @chat.class.connection.adapter_name.match?(/sqlite/i)

        column = @chat.class.connection.quote_column_name(key)
        scope.update_all("#{column} = #{column}")
      end

      def row(path)
        preferred(visible.where(path: path(path)).order(:id).to_a).first
      end

      def preferred(records)
        records.group_by(&:path).values.map { |same| same.find(&:owner_id) || same.first }
      end

      def rows
        ChatFile.where(chat: @chat)
      end

      def visible
        shared = rows.where(owner_type: nil, owner_id: nil)
        @owner ? shared.or(rows.where(owner: @owner)) : shared
      end

      def owned
        @owner ? rows.where(owner: @owner) : rows.where(owner_type: nil, owner_id: nil)
      end

      def inside(folder, scope = visible)
        inside = "#{ChatFile.sanitize_sql_like(folder, '!')}/%"
        scope.where("path = :folder OR path LIKE :inside ESCAPE '!'", folder:, inside:)
      end

      def path(name)
        RubyLLM::FileStore.path(name)
      end

      def blob_of(attachment)
        source = attachment.source
        return source if defined?(::ActiveStorage::Blob) && source.is_a?(::ActiveStorage::Blob)

        source.blob if source.respond_to?(:blob) && source.blob.is_a?(::ActiveStorage::Blob)
      end
    end
  end
end
