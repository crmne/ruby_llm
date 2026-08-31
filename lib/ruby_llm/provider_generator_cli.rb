# frozen_string_literal: true

require 'optparse'
require 'open3'
require 'stringio'
require 'ruby_llm/provider_scaffold'

module RubyLLM
  # Command-line interface for public provider gem generation.
  class ProviderGeneratorCLI
    ACTION_LABELS = { written: 'create', updated: 'update', skipped: 'skip' }.freeze

    class HelpRequested < StandardError; end

    def self.run(argv, out: $stdout, err: $stderr)
      new(argv, out:, err:).run
    end

    def self.parse_options(argv, mode:)
      new(argv, out: StringIO.new, err: StringIO.new).parse_provider_options(mode:)
    end

    def initialize(argv, out:, err:)
      @argv = argv.dup
      @out = out
      @err = err
    end

    def run
      command = @argv.shift

      case command
      when 'provider-gem'
        generate_provider_gem
      when nil, 'help', '-h', '--help'
        @out.puts help
        0
      else
        @err.puts "Unknown command: #{command}"
        @err.puts
        @err.puts help
        1
      end
    rescue HelpRequested => e
      @out.puts e.message
      0
    rescue ArgumentError, OptionParser::ParseError => e
      @err.puts e.message
      1
    end

    def parse_provider_options(mode:)
      options = { mode: mode }
      options[:destination] = Dir.pwd if mode == 'core'
      parser = OptionParser.new
      parser.banner = "Usage: #{command_for(mode)} [options]"
      parser.on('--destination PATH', 'Exact directory to write into') { |value| options[:destination] = value }
      parser.on('--api-base URL', 'Provider API base URL') { |value| options[:api_base] = value }
      parser.on('--api-key-env NAME', 'Environment variable for the provider API key') do |value|
        options[:api_key_env] = value
      end
      parser.on('--api-base-env NAME', 'Environment variable for the provider API base') do |value|
        options[:api_base_env] = value
      end
      parser.on('--dialect NAME', "Wire dialect: #{ProviderScaffold::SUPPORTED_DIALECTS.join(', ')}") do |value|
        options[:dialect] = value
      end
      if mode == 'core'
        parser.on('--models-dev-provider NAME', 'models.dev provider key for first-party core providers') do |value|
          options[:models_dev_provider] = value
        end
      end
      parser.on('--[no-]dynamic-models', 'Allow model ids that are not in the registry') do |value|
        options[:dynamic_models] = value
      end
      if mode == 'gem'
        parser.on('--gem-name NAME', 'RubyGems package name') { |value| options[:gem_name] = value }
        parser.on('--github-owner OWNER', 'GitHub owner or organization for generated metadata') do |value|
          options[:github_owner] = value
        end
        parser.on('--skip-bundle', 'Do not run bundle install') { options[:skip_bundle] = true }
      end
      parser.on('--force', 'Overwrite existing generated files') { options[:force] = true }
      parser.on('-h', '--help', 'Print help') { raise HelpRequested, parser.to_s }

      parser.parse!(@argv)
      name = @argv.shift
      raise ArgumentError, parser.to_s unless name
      raise ArgumentError, "Unexpected arguments: #{@argv.join(' ')}" if @argv.any?

      [name, options]
    end

    private

    def generate_provider_gem
      name, options = parse_provider_options(mode: 'gem')
      skip_bundle = options.delete(:skip_bundle)
      scaffold = ProviderScaffold.new(name, **options)
      destination_existed = Dir.exist?(scaffold.destination)
      result = scaffold.generate

      report_file_actions(result, scaffold.destination, destination_existed:)
      return 1 unless initialize_git_repository(scaffold.destination)
      return 1 unless skip_bundle || install_dependencies(scaffold.destination)

      0
    end

    def report_file_actions(result, destination, destination_existed:)
      report_action(destination_existed ? 'exist' : 'create', destination)
      result.actions.each do |action, path|
        report_action(ACTION_LABELS.fetch(action), path)
      end
    end

    def report_action(action, path)
      @out.puts format('%<action>12s  %<path>s', action:, path:)
    end

    def initialize_git_repository(destination)
      command = git_init_command
      report_action('run', command.join(' '))
      stdout, stderr, status = Open3.capture3(*command, chdir: destination)
      @out.print(stdout)
      @err.print(stderr)
      @err.puts 'Git repository initialization failed.' unless status.success?
      status.success?
    rescue Errno::ENOENT => e
      @err.puts "Git repository initialization failed: #{e.message}"
      false
    end

    def install_dependencies(destination)
      command = %w[bundle install]
      report_action('run', command.join(' '))
      stdout, stderr, status = Open3.capture3(*command, chdir: destination)
      @out.print(stdout)
      @err.print(stderr)
      @err.puts 'Bundle install failed.' unless status.success?
      status.success?
    rescue Errno::ENOENT => e
      @err.puts "Bundle install failed: #{e.message}"
      false
    end

    def git_init_command
      _output, status = Open3.capture2e('git', 'config', '--get', 'init.defaultBranch')
      status.success? ? %w[git init] : %w[git init -b main]
    rescue Errno::ENOENT
      %w[git init]
    end

    def help
      <<~HELP
        Usage:
          ruby_llm provider-gem NAME [options]

        Generates a standalone RubyLLM provider gem with provider code, specs,
        CI, release workflow, ArchSpec, Flay, RuboCop, and live VCR specs.
        Creates ruby_llm-providers-NAME in the current directory by default;
        --destination selects an exact directory. Initializes the target as a
        Git repository and runs bundle install.
      HELP
    end

    def command_for(mode)
      mode == 'core' ? 'script/generate-provider NAME' : 'ruby_llm provider-gem NAME'
    end
  end
end
