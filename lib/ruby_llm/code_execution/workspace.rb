# frozen_string_literal: true

require 'find'
require 'fileutils'
require 'stringio'
require 'tmpdir'

module RubyLLM
  class CodeExecution
    # The directories one run gets: a fresh working directory holding a
    # link, +attachments+, to read-only copies of the conversation's files
    # beside it, or copies of files from a chat's FileStore, and links to
    # read-only mounts, separate home and temporary directories, and the
    # source file. Nothing read-only sits inside the writable working
    # directory, which Landlock could not keep read-only. Everything is
    # removed when the run ends, and so are the links to mounts placed in a
    # store's own folder for a run there.
    class Workspace # :nodoc:
      # Raised when a run cannot have what it asks for.
      class Unavailable < StandardError; end

      ATTACHMENTS = 'attachments'
      IGNORED = %w[__pycache__].freeze
      OPEN_FLAGS = File::RDONLY | File::BINARY | (defined?(File::NOFOLLOW) ? File::NOFOLLOW : 0)

      attr_reader :directory, :home, :tmp, :inputs, :source, :unmounted

      def self.open(attachments: true)
        Dir.mktmpdir('ruby_llm-code-') do |root|
          workspace = new(root, attachments:)
          yield workspace
        ensure
          workspace&.remove_links
          unlock(root)
        end
      end

      def self.unlock(root)
        Find.find(root) do |path|
          File.chmod(0o700, path) if File.lstat(path).directory?
        rescue SystemCallError
          next
        end
      end

      def self.filename(name)
        path = name.to_s.tr('\\', '/')
        return path unless path.empty? || path.split('/', -1).intersect?(['', '.', '..'])

        base = File.basename(path)
        ['', '.', '..'].include?(base) ? 'file' : base
      end

      def initialize(root, attachments: true)
        @directory = File.join(root, 'work')
        @inputs = File.join(root, 'inputs')
        @home = File.join(root, 'home')
        @tmp = File.join(root, 'tmp')
        @source = File.join(root, 'source')
        [@directory, @inputs, @home, @tmp, @source].each { |path| FileUtils.mkdir_p(path) }
        @attachments = File.join(@directory, ATTACHMENTS)
        File.symlink(@inputs, @attachments) if attachments
        @placed = []
        @unmounted = []
      end

      def self.mount_path(name)
        parts = name.to_s.tr('\\', '/').split('/')
        if parts.empty? || name.to_s.start_with?('/') || parts.intersect?(['', '.', '..']) || parts.first == ATTACHMENTS
          raise ArgumentError, "#{name.inspect} is not a path inside the working directory"
        end

        parts.join('/')
      end

      # Links each mount into +into+ and returns the targets. Into a folder
      # other than the working directory, a link reuses one already there
      # to the same target, leaves a path that holds anything else alone
      # (see #unmounted), and is removed with the folders it made by
      # #remove_links.
      def mount(mounts, into: directory)
        mounts.filter_map do |name, path|
          target = File.expand_path(path)
          link = File.join(into, self.class.mount_path(name))
          next target if into == directory ? place(link, target) : place_in_store(link, target, into)

          @unmounted << self.class.mount_path(name)
          nil
        end
      end

      # The mounts left out because the store's folder has a file or folder
      # of its own at their path.

      def remove_links
        @placed.reverse_each do |path, target|
          if target
            File.delete(path) if File.symlink?(path) && File.readlink(path) == target
          else
            Dir.rmdir(path)
          end
        rescue SystemCallError
          next
        end
      end

      def write_source(language, code)
        File.join(source, language.filename).tap { |path| File.write(path, code) }
      end

      def link_packages(node_modules)
        File.symlink(node_modules, File.join(source, 'node_modules'))
      end

      def copy_in(attachments)
        attachments.reject(&:provider_file?).each do |attachment|
          path = File.join(inputs, self.class.filename(attachment.filename))
          make_room(path, inputs)
          File.binwrite(path, attachment.content)
        end
        {}
      end

      def copy_files(store, files)
        files.each_with_object({}) do |file, copied|
          next if file.path.split('/').any? { |part| part.start_with?('.') }

          content = store.read(file.path)
          path = File.join(directory, file.path)
          make_room(path, directory)
          File.binwrite(path, content)
          copied[file.path] = FileStore.digest(content)
        end
      end

      def outputs(max_files:, max_size:, unchanged: {})
        files = []
        skipped = []
        output_paths.each do |path, size|
          name = path.delete_prefix(File.join(directory, ''))
          next if unchanged.key?(name) && unchanged[name] == FileStore.digest(read(path))
          next skipped << "#{name} (larger than #{max_size} bytes)" if size > max_size
          next skipped << "#{name} (more than #{max_files} files)" if files.size >= max_files

          files << Attachment.new(StringIO.new(read(path)), filename: name)
        rescue SystemCallError
          skipped << "#{name} (unreadable)"
        end
        [files, skipped]
      end

      private

      def place(link, target)
        FileUtils.mkdir_p(File.dirname(link))
        File.symlink(target, link)
      end

      def place_in_store(link, target, root)
        return true if File.symlink?(link) && File.readlink(link) == target
        return false if File.symlink?(link) || File.exist?(link)

        make_parents(File.dirname(link), root)
        File.symlink(target, link)
        @placed << [link, target]
        true
      rescue SystemCallError
        false
      end

      def make_parents(folder, root)
        return if folder == root || (File.directory?(folder) && !File.symlink?(folder))
        raise Errno::EEXIST, folder if File.symlink?(folder) || File.exist?(folder)

        make_parents(File.dirname(folder), root)
        Dir.mkdir(folder)
        @placed << [folder, nil]
      end

      def make_room(path, base)
        parent = base
        File.dirname(path).delete_prefix(base).split('/').reject(&:empty?).each do |part|
          parent = File.join(parent, part)
          FileUtils.rm_f(parent) unless File.directory?(parent)
        end
        FileUtils.mkdir_p(File.dirname(path))
        FileUtils.rm_rf(path) if File.directory?(path)
      end

      def output_paths
        paths = []
        Find.find(directory) do |path|
          name = File.basename(path)
          Find.prune if path == @attachments || IGNORED.include?(name) || (path != directory && name.start_with?('.'))
          size = output_size(path)
          paths << [path, size] if size
        end
        paths.sort
      end

      def output_size(path)
        stat = File.lstat(path)
        return stat.size if stat.file?

        0 if stat.directory? && !(stat.readable? && stat.executable?)
      rescue SystemCallError
        0
      end

      def read(path)
        File.open(path, OPEN_FLAGS, &:read).b
      end
    end
  end
end
