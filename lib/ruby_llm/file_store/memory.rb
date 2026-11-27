# frozen_string_literal: true

module RubyLLM
  class FileStore
    # Keeps files in memory, for as long as the chat lives. It is the
    # store Chat#with_file_store uses when given none.
    #
    #   chat.with_file_store(:memory)
    #
    class Memory < FileStore
      def initialize # :nodoc:
        super
        @files = {}
        @lock = Mutex.new
      end

      # Returns the files inside the folder +prefix+, or every file.
      def list(prefix = nil)
        @lock.synchronize { @files.values.map(&:first) }
             .select { |file| FileStore.inside?(file.path, prefix) }
             .sort_by(&:path)
      end

      # Returns the StoredFile at +path+, or +nil+.
      def [](path)
        @lock.synchronize { @files[FileStore.path(path)]&.first }
      end

      # Returns the content of the file at +path+.
      def read(path)
        path = FileStore.path(path)
        content = @lock.synchronize { @files[path]&.last }
        raise FileNotFoundError, "No file at #{path}" unless content

        content.dup
      end

      # Writes +content+ to +path+ and returns its StoredFile.
      def write(path, content, content_type: nil)
        path = FileStore.path(path)
        content = FileStore.bytes(content).freeze
        file = StoredFile.new(path:, byte_size: content.bytesize,
                              content_type: content_type || FileStore.content_type_for(path, content),
                              digest: FileStore.digest(content), updated_at: Time.now)
        with_lock do
          @lock.synchronize do
            refuse_write_over_folder(path) if holds_folder?(path)
            @files[path] = [file, content]
          end
        end
        file
      end

      # Deletes the file at +path+ and returns its StoredFile, or +nil+.
      def delete(path)
        path = FileStore.path(path)
        with_lock do
          @lock.synchronize do
            refuse_folder(path) if !@files.key?(path) && @files.keys.any? { |key| FileStore.inside?(key, path) }
            @files.delete(path)&.first
          end
        end
      end

      # Deletes everything inside the folder +path+ and returns the deleted
      # StoredFile objects.
      def delete_folder(path)
        path = FileStore.path(path)
        with_lock do
          @lock.synchronize do
            refuse_file(path) if @files.key?(path)

            paths = @files.keys.select { |key| FileStore.inside?(key, path) }
            paths.map { |key| @files.delete(key).first }.sort_by(&:path)
          end
        end
      end

      private

      def folder?(path)
        @lock.synchronize { holds_folder?(path) }
      end

      def holds_folder?(path)
        @files.each_key.any? { |key| key != path && FileStore.inside?(key, path) }
      end
    end
  end
end
