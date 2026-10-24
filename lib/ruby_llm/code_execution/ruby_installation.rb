# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'open3'
require 'rbconfig'
require 'tmpdir'

module RubyLLM
  class CodeExecution
    # The application's Ruby, as code execution mounts it: the installation
    # read-only, with every gem in its gem directory hidden except Ruby's
    # default and bundled gems, and every other gem directory the
    # application uses hidden entirely. RubyGems lists the plugins
    # directory on every +gem+ command, so only the application's plugins
    # are hidden, not the directory: macOS refuses to list a hidden one.
    # The libraries its extensions link outside the installation, such as
    # Homebrew's OpenSSL and libyaml on macOS, are mounted read-only too.
    class RubyInstallation # :nodoc:
      HIDDEN_DIRECTORIES = %w[cache doc].freeze
      BUILD_MARKER = 'gem.build_complete'

      def self.current
        @current ||= new
      end

      def initialize(prefix: RbConfig::CONFIG['prefix'], gem_dir: Gem.default_dir, gem_path: Gem.path,
                     archdir: RbConfig::CONFIG['rubyarchdir'])
        @prefix = prefix
        @gem_dir = gem_dir
        @gem_path = gem_path
        @archdir = archdir
      end

      def readable
        installation = @gem_dir.start_with?(File.join(@prefix, '')) ? [@prefix] : [@prefix, @gem_dir]
        installation + library_directories
      end

      def denied
        @denied ||= [
          *application_gems.flat_map { |stub| gem_paths(stub) },
          *HIDDEN_DIRECTORIES.map { |name| File.join(@gem_dir, name) },
          *(@gem_path - [@gem_dir])
        ].select { |path| File.exist?(path) }.uniq.freeze
      end

      # Returns a directory, built once under +cache_dir+, or under a
      # private temporary directory without one, that holds only Ruby's
      # bundled gems: their gemspecs, and links to their files. A GEM_PATH
      # with it instead of the gem directory finds no hidden application
      # gem, so <tt>gem install</tt> installs every dependency and RubyGems
      # never activates a gem whose files the sandbox hides. Default gems
      # load from any GEM_PATH.
      def ruby_gems(cache_dir)
        cache_dir ||= (@private_dir ||= Dir.mktmpdir('ruby_llm-ruby-gems-'))
        directory = File.join(cache_dir, "bundled-gems-#{ruby_gems_key}")
        return directory if File.exist?("#{directory}.ready")

        FileUtils.mkdir_p(cache_dir)
        File.open("#{directory}.lock", File::RDWR | File::CREAT, 0o644) do |lock|
          lock.flock(File::LOCK_EX)
          link_ruby_gems(directory) unless File.exist?("#{directory}.ready")
        end
        directory
      end

      def ruby_gem?(name)
        default_gems.include?(name) || bundled_gems.include?(name)
      end

      private

      def library_directories
        @library_directories ||= linked_libraries.filter_map do |library|
          path = File.realpath(library)
          next if path.start_with?(File.join(File.realpath(@prefix), ''))

          File.dirname(path)
        rescue SystemCallError
          nil
        end.uniq
      end

      def linked_libraries
        return [] unless @archdir && RUBY_PLATFORM.include?('darwin')

        bundles = Dir.glob(File.join(@archdir, '**', '*.bundle'))
        return [] if bundles.empty? || !developer_tools?

        output, status = Open3.capture2('otool', '-L', *bundles, err: File::NULL)
        return [] unless status.success?

        output.lines.filter_map { |line| line[/\A\s+(.+) \(compatibility version /, 1] }
      rescue SystemCallError
        []
      end

      # Without the Command Line Tools, macOS answers +otool+ with a dialog
      # offering to install them.
      def developer_tools?
        Kernel.system('xcode-select', '-p', out: File::NULL, err: File::NULL)
      end

      def application_gems
        installed_stubs.reject { |stub| ruby_gem?(stub.name) }
      end

      def installed_stubs
        Dir.glob(File.join(@gem_dir, 'specifications', '*.gemspec')).map do |path|
          Gem::StubSpecification.gemspec_stub(path, @gem_dir, File.join(@gem_dir, 'gems'))
        end
      end

      def bundled_gem_stubs
        installed_stubs.select { |stub| bundled_gems.include?(stub.name) && !default_gems.include?(stub.name) }
      end

      def ruby_gems_key
        Digest::SHA256.hexdigest([RbConfig.ruby, RUBY_VERSION, *bundled_gem_stubs.map(&:full_name)].join("\n"))[0, 24]
      end

      def link_ruby_gems(directory)
        FileUtils.rm_rf(directory)
        FileUtils.mkdir_p(File.join(directory, 'specifications'))
        bundled_gem_stubs.each do |stub|
          [File.join(@gem_dir, 'gems', stub.full_name), extensions_dir(stub)].each do |path|
            next unless File.exist?(path)

            link = File.join(directory, path.delete_prefix(File.join(@gem_dir, '')))
            FileUtils.mkdir_p(File.dirname(link))
            File.symlink(path, link)
          end
          FileUtils.cp(stub.loaded_from, File.join(directory, 'specifications'))
        end
        File.write("#{directory}.ready", '')
      end

      def extensions_dir(stub)
        File.join(@gem_dir, 'extensions', Gem::Platform.local.to_s, Gem.extension_api_version, stub.full_name)
      end

      def gem_paths(stub)
        extensions = extensions_dir(stub)
        built = Dir.exist?(extensions) ? Dir.children(extensions) - [BUILD_MARKER] : []
        [File.join(@gem_dir, 'gems', stub.full_name), *built.map { |name| File.join(extensions, name) },
         File.join(@gem_dir, 'plugins', "#{stub.name}_plugin.rb")]
      end

      def default_gems
        @default_gems ||= Dir.glob(File.join(@gem_dir, 'specifications', 'default', '*.gemspec')).map do |path|
          Gem::StubSpecification.default_gemspec_stub(path, @gem_dir, File.join(@gem_dir, 'gems')).name
        end
      end

      def bundled_gems
        @bundled_gems ||= bundled_gems_file || bundled_gems_constant
      end

      def bundled_gems_file
        path = File.join(RbConfig::CONFIG['srcdir'].to_s, 'gems', 'bundled_gems')
        return unless File.file?(path)

        File.readlines(path).filter_map { |line| line.split.first unless line.start_with?('#') || line.strip.empty? }
      end

      def bundled_gems_constant
        require 'bundled_gems' unless defined?(Gem::BUNDLED_GEMS)
        Gem::BUNDLED_GEMS::SINCE.keys
      rescue LoadError, NameError
        []
      end
    end
  end
end
