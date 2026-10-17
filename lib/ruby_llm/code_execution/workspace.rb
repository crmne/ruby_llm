# frozen_string_literal: true

require 'find'
require 'fileutils'
require 'stringio'
require 'tmpdir'

module RubyLLM
  class CodeExecution
    # The directories one run gets: a fresh working directory holding a
    # link, +attachments+, to read-only copies of the conversation's files
    # beside it, or copies of a chat's FileStore, and links to read-only
    # mounts, separate home and temporary directories, and the source file. Nothing read-only sits inside the
    # writable working directory, which Landlock could not keep read-only.
    # Everything is removed when the run ends.
    class Workspace # :nodoc:
      ATTACHMENTS = 'attachments'
      IGNORED = %w[__pycache__].freeze
      OPEN_FLAGS = File::RDONLY | File::BINARY | (defined?(File::NOFOLLOW) ? File::NOFOLLOW : 0)

      attr_reader :directory, :home, :tmp, :inputs, :source

      def self.open(attachments: true)
        Dir.mktmpdir('ruby_llm-code-') do |root|
          yield new(root, attachments:)
        ensure
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
      end

      def self.mount_path(name)
        parts = name.to_s.tr('\\', '/').split('/')
        if parts.empty? || name.to_s.start_with?('/') || parts.intersect?(['', '.', '..']) || parts.first == ATTACHMENTS
          raise ArgumentError, "#{name.inspect} is not a path inside the working directory"
        end

        parts.join('/')
      end

      def mount(mounts)
        mounts.map do |name, path|
          link = File.join(directory, self.class.mount_path(name))
          FileUtils.mkdir_p(File.dirname(link))
          File.expand_path(path).tap { |target| File.symlink(target, link) }
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

      def copy_files(store, skip: [])
        store.list.each_with_object({}) do |file, copied|
          next if file.path.split('/').any? { |part| part.start_with?('.') }
          next if skip.any? { |mount| FileStore.inside?(file.path, mount) || FileStore.inside?(mount, file.path) }

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
