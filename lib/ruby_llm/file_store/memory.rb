# frozen_string_literal: true

module RubyLLM
  class FileStore
    # Keeps files in memory, for as long as the chat lives. It is the
    # store Chat#with_files uses when given none.
    #
    #   chat.with_files(store: RubyLLM::FileStore::Memory.new)
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
      def find(path)
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
        @lock.synchronize { @files[path] = [file, content] }
        file
      end

      # Deletes the file at +path+ and returns its StoredFile, or +nil+.
      def delete(path)
        @lock.synchronize { @files.delete(FileStore.path(path))&.first }
      end
    end
  end
end
