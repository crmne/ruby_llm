# frozen_string_literal: true

require 'rbconfig'

module RubyLLM
  class CodeExecution
    # The application's Ruby, as code execution mounts it: the installation
    # read-only, with every gem in its gem directory hidden except Ruby's
    # default and bundled gems, and every other gem directory the
    # application uses hidden entirely.
    class RubyInstallation # :nodoc:
      HIDDEN_DIRECTORIES = %w[cache doc plugins].freeze
      BUILD_MARKER = 'gem.build_complete'

      def self.current
        @current ||= new
      end

      def initialize(prefix: RbConfig::CONFIG['prefix'], gem_dir: Gem.default_dir, gem_path: Gem.path)
        @prefix = prefix
        @gem_dir = gem_dir
        @gem_path = gem_path
      end

      def readable
        @gem_dir.start_with?(File.join(@prefix, '')) ? [@prefix] : [@prefix, @gem_dir]
      end

      def denied
        @denied ||= [
          *application_gems.flat_map { |stub| gem_paths(stub) },
          *HIDDEN_DIRECTORIES.map { |name| File.join(@gem_dir, name) },
          *(@gem_path - [@gem_dir])
        ].select { |path| File.exist?(path) }.uniq.freeze
      end

      def ruby_gem?(name)
        default_gems.include?(name) || bundled_gems.include?(name)
      end

      private

      def application_gems
        Dir.glob(File.join(@gem_dir, 'specifications', '*.gemspec')).filter_map do |path|
          stub = Gem::StubSpecification.gemspec_stub(path, @gem_dir, File.join(@gem_dir, 'gems'))
          stub unless ruby_gem?(stub.name)
        end
      end

      def gem_paths(stub)
        extensions = File.join(@gem_dir, 'extensions', Gem::Platform.local.to_s, Gem.extension_api_version,
                               stub.full_name)
        built = Dir.exist?(extensions) ? Dir.children(extensions) - [BUILD_MARKER] : []
        [File.join(@gem_dir, 'gems', stub.full_name), *built.map { |name| File.join(extensions, name) }]
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
