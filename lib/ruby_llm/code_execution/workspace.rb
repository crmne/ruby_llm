# frozen_string_literal: true

require 'find'
require 'fileutils'
require 'stringio'
require 'tmpdir'

module RubyLLM
  class CodeExecution
    # The directories one run gets: a fresh working directory holding
    # read-only copies of the conversation's files under +attachments+ and
    # links to read-only mounts, separate home and temporary directories,
    # and the source file. Everything is removed when the run ends.
    class Workspace # :nodoc:
      ATTACHMENTS = 'attachments'
      IGNORED = %w[__pycache__].freeze
      OPEN_FLAGS = File::RDONLY | File::BINARY | (defined?(File::NOFOLLOW) ? File::NOFOLLOW : 0)

      attr_reader :directory, :home, :tmp, :inputs, :source

      def self.open
        Dir.mktmpdir('ruby_llm-code-') { |root| yield new(root) }
      end

      def self.filename(name)
        base = File.basename(name.to_s.tr('\\', '/'))
        ['', '.', '..'].include?(base) ? 'file' : base
      end

      def initialize(root)
        @directory = File.join(root, 'work')
        @inputs = File.join(@directory, ATTACHMENTS)
        @home = File.join(root, 'home')
        @tmp = File.join(root, 'tmp')
        @source = File.join(root, 'source')
        [@inputs, @home, @tmp, @source].each { |path| FileUtils.mkdir_p(path) }
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

      def copy_in(attachments)
        attachments.reject(&:provider_file?).each do |attachment|
          File.binwrite(File.join(inputs, self.class.filename(attachment.filename)), attachment.content)
        end
      end

      def outputs(max_files:, max_size:)
        files = []
        skipped = []
        output_paths.each do |path, size|
          name = path.delete_prefix(File.join(directory, ''))
          next skipped << "#{name} (larger than #{max_size} bytes)" if size > max_size
          next skipped << "#{name} (more than #{max_files} files)" if files.size >= max_files

          files << Attachment.new(StringIO.new(read(path)), filename: name)
        end
        [files, skipped]
      end

      private

      def output_paths
        paths = []
        Find.find(directory) do |path|
          name = File.basename(path)
          Find.prune if path == inputs || IGNORED.include?(name) || (path != directory && name.start_with?('.'))
          stat = File.lstat(path)
          paths << [path, stat.size] if stat.file?
        end
        paths.sort
      end

      def read(path)
        File.open(path, OPEN_FLAGS, &:read).b
      end
    end
  end
end
