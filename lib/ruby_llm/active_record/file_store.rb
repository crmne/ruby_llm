# frozen_string_literal: true

require 'stringio'

module RubyLLM
  module ActiveRecord
    # Keeps a persisted chat's files in +ruby_llm_chat_files+, with their
    # content in Active Storage, so they live on whatever service Active
    # Storage uses: a disk now, a bucket later. A persisted chat uses one
    # when ChatMethods#with_files is given no store.
    #
    #   chat.with_files
    #   chat.files.list
    #
    # With +owner:+, the store writes files for that owner and sees only
    # their files and the files without an owner, so in a chat several
    # people share, one person's tool results stay theirs:
    #
    #   chat.with_files(store: chat.file_store(owner: Current.user))
    #
    # Converted text is kept in the row's +text+ column. Encrypt it, like
    # anything else the model reads, with
    # <tt>RubyLLM::ActiveRecord::ChatFile.encrypts :text</tt>.
    class FileStore < RubyLLM::FileStore
      # The chat record the files belong to.
      attr_reader :chat

      # The owner the store writes files for, or +nil+.
      attr_reader :owner

      # Creates a store for the files of the +chat+ record, writing them for
      # +owner+ when given.
      def initialize(chat, owner: nil)
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
      def find(path)
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

      # Deletes the file at +path+ and returns its StoredFile, or +nil+.
      def delete(path)
        record = owned.find_by(path: path(path))
        record&.destroy
        record&.to_stored_file
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

      def write_attachment(path, attachment, content)
        blob = blob_of(attachment)
        return super unless blob

        save(path, blob.byte_size, attachment.mime_type, RubyLLM::FileStore.digest(content)) do |record|
          record.file.attach(blob)
        end
      end

      def save(path, byte_size, content_type, digest)
        ChatFile.transaction do
          record = owned.find_or_initialize_by(path:)
          record.assign_attributes(byte_size:, content_type:, digest:)
          record.text = nil if record.has_attribute?(:text)
          yield record
          record.save!
          record.to_stored_file
        end
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

      def inside(folder)
        visible.where('path = :folder OR path LIKE :inside', folder:,
                                                             inside: "#{ChatFile.sanitize_sql_like(folder)}/%")
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
