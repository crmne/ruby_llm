# frozen_string_literal: true

require 'optparse'
require 'stringio'
require 'ruby_llm/provider_scaffold'

module RubyLLM
  # Command-line interface for public provider gem generation.
  class ProviderGeneratorCLI
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
      options = {
        mode: mode,
        destination: Dir.pwd
      }
      parser = OptionParser.new
      parser.banner = "Usage: #{command_for(mode)} [options]"
      parser.on('--destination PATH', 'Directory to write into') { |value| options[:destination] = value }
      parser.on('--api-base URL', 'Provider API base URL') { |value| options[:api_base] = value }
      parser.on('--model ID', 'Example model id for generated specs') { |value| options[:model] = value }
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
      result = ProviderScaffold.new(name, **options).generate!

      @out.puts "Generated #{result.changed.size} files in #{File.expand_path(options[:destination])}"
      @out.puts "Skipped #{result.skipped.size} existing files" if result.skipped.any?
      0
    end

    def help
      <<~HELP
        Usage:
          ruby_llm provider-gem NAME [options]

        Generates a standalone RubyLLM provider gem with provider code, specs,
        CI, release workflow, Appraisal, ArchSpec, Flay, RuboCop, and VCR setup.
      HELP
    end

    def command_for(mode)
      mode == 'core' ? 'script/generate-provider NAME' : 'ruby_llm provider-gem NAME'
    end
  end
end
