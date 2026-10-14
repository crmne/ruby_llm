# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'rbconfig'
require 'tmpdir'

module RubyLLM
  class CodeExecution
    # The Ruby installation, gems, and Python packages code runs with.
    # Declared gems and Python packages are installed once per set, in the
    # sandbox with only their registries reachable, into a directory under
    # Configuration#package_cache_dir that every later run mounts read-only.
    # A prebuilt GEM_HOME or virtualenv is mounted as it is.
    class Packages # :nodoc:
      SYSTEM_PATH = %w[/usr/local/bin /usr/bin /bin].freeze
      INSTALL_TIMEOUT = 600
      REGISTRIES = {
        ruby: %w[rubygems.org *.rubygems.org],
        python: %w[pypi.org files.pythonhosted.org]
      }.freeze

      attr_reader :gems, :python

      def initialize(sandbox:, cache_dir:, gems: [], python: [], gem_home: nil, virtualenv: nil)
        @sandbox = sandbox
        @cache_dir = cache_dir
        @gems = Array(gems).map(&:to_s)
        @python = Array(python).map(&:to_s)
        @gem_home = gem_home && File.expand_path(gem_home)
        @virtualenv = virtualenv && File.expand_path(virtualenv)
        @lock = Mutex.new
      end

      def gem_names
        return gems if gems.any? || @gem_home.nil?

        Dir.glob(File.join(@gem_home, 'specifications', '*.gemspec'))
           .map { |path| File.basename(path, '.gemspec').sub(/-[^-]+\z/, '') }.uniq.sort
      end

      def python_names
        return python if python.any? || @virtualenv.nil?

        Dir.glob(File.join(@virtualenv, 'lib', 'python*', 'site-packages', '*.dist-info'))
           .map { |path| File.basename(path, '.dist-info').sub(/-[^-]+\z/, '') }.uniq.sort
      end

      def readable
        [*ruby_directories, gem_home, virtualenv].compact
      end

      def env(home, tmp = home)
        base_env(home, tmp).merge(
          'PATH' => path,
          'GEM_PATH' => gem_home && [gem_home, Gem.default_dir].join(File::PATH_SEPARATOR),
          'VIRTUAL_ENV' => virtualenv
        ).compact
      end

      def gem_home
        return @gem_home if gems.empty?

        @lock.synchronize { @installed_gem_home ||= install(:ruby, gems) }
      end

      def virtualenv
        return @virtualenv if python.empty?

        @lock.synchronize { @installed_virtualenv ||= install(:python, python) }
      end

      def base_env(home, tmp = home)
        {
          'PATH' => [RbConfig::CONFIG['bindir'], *SYSTEM_PATH].join(File::PATH_SEPARATOR),
          'HOME' => home,
          'XDG_CACHE_HOME' => File.join(home, '.cache'),
          'TMPDIR' => tmp,
          'LANG' => 'C.UTF-8'
        }
      end

      def run(*command, home:, writable: [], network: false, env: {})
        @sandbox.run(*command, readable: ruby_directories, writable: [*writable, home], network:,
                               env: base_env(home).merge(env), timeout: INSTALL_TIMEOUT)
      end

      private

      def ruby_directories
        prefix = RbConfig::CONFIG['prefix']
        gem_dir = Gem.default_dir
        gem_dir.start_with?(File.join(prefix, '')) ? [prefix] : [prefix, gem_dir]
      end

      def path
        [virtualenv && File.join(virtualenv, 'bin'), gem_home && File.join(gem_home, 'bin'),
         RbConfig::CONFIG['bindir'], *SYSTEM_PATH].compact.join(File::PATH_SEPARATOR)
      end

      def install(kind, packages)
        directory = File.join(cache_dir, "#{kind}-#{cache_key(kind, packages)}")
        return directory if File.exist?("#{directory}.ready")

        FileUtils.mkdir_p(cache_dir)
        File.open("#{directory}.lock", File::RDWR | File::CREAT, 0o644) do |lock|
          lock.flock(File::LOCK_EX)
          build(kind, directory, packages) unless File.exist?("#{directory}.ready")
        end
        directory
      end

      def build(kind, directory, packages)
        FileUtils.rm_rf(directory)
        FileUtils.mkdir_p(directory)
        Dir.mktmpdir('ruby_llm-install-') do |home|
          kind == :ruby ? install_gems(directory, packages, home) : install_python(directory, packages, home)
        end
        File.write("#{directory}.ready", "#{packages.sort.join("\n")}\n")
      end

      def install_gems(directory, gems, home)
        result = run('ruby', '-S', 'gem', 'install', '--no-document', '--install-dir', directory,
                     '--bindir', File.join(directory, 'bin'), *gems,
                     home:, writable: [directory], network: { allow: REGISTRIES[:ruby] },
                     env: { 'GEM_HOME' => directory, 'GEM_PATH' => directory })
        verify(result, "gems #{gems.join(', ')}")
      end

      def install_python(directory, packages, home)
        description = "Python packages #{packages.join(', ')}"
        verify(run('python3', '-m', 'venv', directory, home:, writable: [directory]), description)
        result = run(File.join(directory, 'bin', 'python'), '-m', 'pip', 'install', '--no-input',
                     '--disable-pip-version-check', *packages,
                     home:, writable: [directory], network: { allow: REGISTRIES[:python] })
        verify(result, description)
      end

      def verify(result, description)
        return if result.exit_code&.zero? && !result.timed_out?

        raise Error, "Could not install #{description}: #{failure(result)}"
      end

      def failure(result)
        return "timed out after #{INSTALL_TIMEOUT} seconds" if result.timed_out?

        stderr = result.stderr.to_s.strip
        blocked = result.respond_to?(:blocked) ? Array(result.blocked) : []
        details = stderr[[stderr.length - 2000, 0].max..]
        blocked.empty? ? details : "#{details} (blocked: #{blocked.join(', ')})"
      end

      def cache_key(kind, packages)
        Digest::SHA256.hexdigest(JSON.generate([kind, runtime_version(kind), packages.sort]))[0, 24]
      end

      def runtime_version(kind)
        return [RUBY_VERSION, RUBY_PLATFORM, RbConfig.ruby] if kind == :ruby

        Dir.mktmpdir('ruby_llm-install-') do |home|
          run('python3', '-c', 'import sys; print(sys.version)', home:).stdout.to_s.strip
        end
      end

      def cache_dir
        @cache_dir || raise(ConfigurationError, 'Set config.package_cache_dir to install code execution packages')
      end
    end
  end
end
