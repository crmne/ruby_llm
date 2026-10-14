# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

module RubyLLM
  class CodeExecution
    # The writable place a chat's runs install packages into once its
    # permissions grant network access: a GEM_HOME for <tt>gem install</tt>
    # and a virtualenv for <tt>pip install</tt>, kept under
    # Configuration#package_cache_dir by the chat's grants, so every later
    # run in the chat, in any process, finds what earlier runs installed.
    # Its GEM_PATH leaves out Ruby's gem directory, where the application's
    # hidden gems would pass for installed ones, for a copy that holds only
    # Ruby's bundled gems.
    class Environment # :nodoc:
      attr_reader :directory

      def initialize(packages, id, installation: RubyInstallation.current)
        @packages = packages
        @installation = installation
        @directory = File.join(packages.cache_dir, 'chats', id)
      end

      def gem_home
        File.join(directory, 'gems')
      end

      def virtualenv
        File.join(directory, 'python')
      end

      def writable
        [directory]
      end

      def readable
        [@ruby_gems].compact
      end

      def prepare(python:)
        FileUtils.mkdir_p(gem_home)
        @ruby_gems = @installation.ruby_gems(@packages.cache_dir)
        create_virtualenv if python && !File.exist?(ready_marker)
      end

      def env(base)
        python = File.exist?(ready_marker)
        base.merge(
          'GEM_HOME' => gem_home,
          'GEM_PATH' => [gem_home, @packages.gem_home, @ruby_gems].compact.join(File::PATH_SEPARATOR),
          'PATH' => [(File.join(virtualenv, 'bin') if python), File.join(gem_home, 'bin'), base['PATH']]
                    .compact.join(File::PATH_SEPARATOR),
          'VIRTUAL_ENV' => (python ? virtualenv : base['VIRTUAL_ENV'])
        ).compact
      end

      private

      def ready_marker
        File.join(directory, 'python.ready')
      end

      def create_virtualenv
        File.open(File.join(directory, 'python.lock'), File::RDWR | File::CREAT, 0o644) do |lock|
          lock.flock(File::LOCK_EX)
          build_virtualenv unless File.exist?(ready_marker)
        end
      end

      def build_virtualenv
        FileUtils.rm_rf(virtualenv)
        Dir.mktmpdir('ruby_llm-install-') do |home|
          result = @packages.run('python3', '-m', 'venv', virtualenv, home:, writable: [directory])
          unless result.exit_code&.zero? && !result.timed_out?
            raise Error, "Could not create the chat's Python environment: #{result.stderr.to_s.strip}"
          end
        end
        link_declared_packages
        File.write(ready_marker, '')
      end

      def link_declared_packages
        declared = @packages.virtualenv
        return unless declared

        source = Dir.glob(File.join(declared, 'lib', 'python*', 'site-packages')).first
        target = Dir.glob(File.join(virtualenv, 'lib', 'python*', 'site-packages')).first
        File.write(File.join(target, 'ruby_llm_declared.pth'), "#{source}\n") if source && target
      end
    end
  end
end
