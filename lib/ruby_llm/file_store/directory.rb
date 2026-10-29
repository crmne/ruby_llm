# frozen_string_literal: true

require 'fileutils'
require 'find'

module RubyLLM
  class FileStore
    # Keeps files in a folder on disk, created when missing. Files someone
    # puts in the folder are the chat's files too. Hidden files and
    # folders, whose names start with a dot, are left out, and symbolic
    # links are never followed. Code execution runs in the folder itself
    # and can change anything in it, so give each store a folder of its
    # own.
    #
    #   chat.with_file_store(RubyLLM.file_store.directory("tmp/chats/42"))
    #
    class Directory < FileStore
      OPEN_FLAGS = File::RDONLY | File::BINARY | (defined?(File::NOFOLLOW) ? File::NOFOLLOW : 0)
      SNIFF_FLAGS = OPEN_FLAGS | (defined?(File::NONBLOCK) ? File::NONBLOCK : 0)
      private_constant :OPEN_FLAGS, :SNIFF_FLAGS

      # The folder holding the files, as an absolute path.
      attr_reader :root

      # Creates a store for the folder +root+.
      def initialize(root)
        super()
        FileUtils.mkdir_p(root)
        @root = File.realpath(root)
      end

      # Returns #root: code execution runs in this folder.
      def local_root
        root
      end

      # Returns the files inside the folder +prefix+, or every file.
      def list(prefix = nil)
        start = prefix.to_s.empty? ? root : full_path(FileStore.path(prefix))
        return [find(prefix)].compact unless File.lstat(start).directory?

        walk(start).sort_by(&:path)
      rescue SystemCallError
        []
      end

      # Returns the StoredFile at +path+, or +nil+.
      def find(path)
        full = full_path(FileStore.path(path))
        stat = File.lstat(full)
        stored_file(full, stat) if stat.file?
      rescue SystemCallError
        nil
      end

      # Returns the content of the file at +path+.
      def read(path)
        path = FileStore.path(path)
        File.open(full_path(path), OPEN_FLAGS, &:read).b
      rescue SystemCallError
        raise FileNotFoundError, "No file at #{path}"
      end

      # Writes +content+ to +path+ and returns its StoredFile.
      def write(path, content, content_type: nil)
        path = FileStore.path(path)
        full = full_path(path)
        make_room(full)
        content = FileStore.bytes(content)
        temporary = File.join(File.dirname(full),
                              ".#{File.basename(full)}.#{Process.pid}.#{Thread.current.object_id}.tmp")
        File.binwrite(temporary, content)
        File.rename(temporary, full)
        file = stored_file(full, File.lstat(full))
        return file unless content_type

        StoredFile.new(**file.to_h, content_type:)
      ensure
        FileUtils.rm_f(temporary) if temporary
      end

      # Deletes the file at +path+ and returns its StoredFile, or +nil+.
      def delete(path)
        file = find(path)
        File.delete(full_path(file.path)) if file
        file
      end

      private

      def full_path(path)
        parent = root
        path.split('/').each do |part|
          raise ArgumentError, "#{path} is not inside the chat's files" if part.start_with?('.')

          parent = File.join(parent, part)
        end
        folder = File.dirname(parent)
        if File.directory?(folder) && !"#{File.realpath(folder)}/".start_with?("#{root}/")
          raise ArgumentError, "#{path} is not inside the chat's files"
        end

        parent
      end

      def walk(start)
        files = []
        Find.find(start) do |path|
          next if path == root

          stat = File.lstat(path)
          Find.prune if File.basename(path).start_with?('.')
          files << stored_file(path, stat) if stat.file?
        end
        files
      end

      def make_room(full)
        parent = root
        File.dirname(full).delete_prefix(root).split('/').reject(&:empty?).each do |part|
          parent = File.join(parent, part)
          File.delete(parent) if File.symlink?(parent) || File.file?(parent)
        end
        FileUtils.mkdir_p(File.dirname(full))
        FileUtils.rm_rf(full) if File.directory?(full) || File.symlink?(full)
      end

      def file_content_type(full, path)
        type = FileStore.content_type_for(path, '')
        return type unless type == 'application/octet-stream'

        File.open(full, SNIFF_FLAGS) { |io| io.stat.file? ? Files::MimeType.for(io, name: path) : type }
      rescue SystemCallError
        type
      end

      def stored_file(full, stat)
        path = full.delete_prefix("#{root}/")
        StoredFile.new(path:, byte_size: stat.size, content_type: file_content_type(full, path),
                       updated_at: stat.mtime)
      end
    end
  end
end
