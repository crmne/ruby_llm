# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'pathname'
require 'ruby_llm/utils'
require 'ruby_llm/version'

module RubyLLM
  # Generates first-party providers and standalone provider gems.
  class ProviderScaffold
    SUPPORTED_MODES = %w[core gem].freeze
    SUPPORTED_DIALECTS = %w[chat_completions responses anthropic gemini converse ollama].freeze
    TEMPLATE_ROOT = File.expand_path('../generators/ruby_llm/provider/templates', __dir__)

    Result = Struct.new(:written, :updated, :skipped, keyword_init: true) do
      def changed
        written + updated
      end
    end

    attr_reader :name, :mode, :destination, :api_base, :model, :api_key_env, :api_base_env,
                :dialect, :models_dev_provider, :gem_name, :github_owner

    def initialize(name, **options)
      @name = name.to_s.strip
      raise ArgumentError, 'provider name is required' if @name.empty?

      @mode = normalize_option(options.fetch(:mode, :core), SUPPORTED_MODES, 'mode')
      @dialect = normalize_option(options.fetch(:dialect, :chat_completions), SUPPORTED_DIALECTS, 'dialect')
      @destination = File.expand_path(options.fetch(:destination, Dir.pwd))
      @api_base = options[:api_base] || 'https://api.example.com/v1'
      @model = options[:model] || 'example-chat-model'
      @api_key_env = options[:api_key_env] || "#{env_prefix}_API_KEY"
      @api_base_env = options[:api_base_env] || "#{env_prefix}_API_BASE"
      @models_dev_provider = blank_to_nil(options[:models_dev_provider])
      @dynamic_models = dynamic_models_option?(options)
      @gem_name = options[:gem_name] || "ruby_llm-#{slug.tr('_', '-')}"
      @github_owner = options[:github_owner] || 'your-github-org'
      @force = options.fetch(:force, false)
      @result = Result.new(written: [], updated: [], skipped: [])
    end

    def generate!
      mode == 'core' ? generate_core_provider : generate_provider_gem
      @result
    end

    def class_name
      @class_name ||= classify(name)
    end

    def slug
      @slug ||= RubyLLM::Utils.underscore(class_name).tr('-', '_')
    end

    def env_prefix
      slug.upcase
    end

    def api_key_config
      "#{slug}_api_key"
    end

    def api_base_config
      "#{slug}_api_base"
    end

    def dynamic_models?
      !!@dynamic_models
    end

    def protocol_name
      dialect == 'ollama' ? 'chat_completions' : dialect
    end

    def protocol_class_name
      {
        'chat_completions' => 'ChatCompletions',
        'responses' => 'Responses',
        'anthropic' => 'Anthropic',
        'gemini' => 'Gemini',
        'converse' => 'Converse',
        'ollama' => 'ChatCompletions'
      }.fetch(dialect)
    end

    def protocol_superclass
      {
        'chat_completions' => 'Protocols::ChatCompletions',
        'responses' => 'Protocols::Responses',
        'anthropic' => 'Protocols::Anthropic',
        'gemini' => 'Protocols::Gemini',
        'converse' => 'Protocols::Converse',
        'ollama' => 'Ollama::ChatCompletions'
      }.fetch(dialect)
    end

    def provider_description
      "#{class_name} API integration."
    end

    def require_path
      "ruby_llm/#{slug}"
    end

    def version_namespace
      class_name
    end

    def ruby_llm_minimum_version
      RubyLLM::VERSION.split('.').first(2).join('.')
    end

    private

    def generate_core_provider
      write_template 'core/provider.rb.erb', "lib/ruby_llm/providers/#{slug}.rb"
      write_template 'shared/capabilities.rb.erb', "lib/ruby_llm/providers/#{slug}/capabilities.rb"
      write_template 'core/provider_spec.rb.erb', "spec/ruby_llm/providers/#{slug}_spec.rb"
      write_template 'shared/capabilities_spec.rb.erb', "spec/ruby_llm/providers/#{slug}/capabilities_spec.rb"

      update_core_registration
      update_core_env_example
      update_core_spec_configuration
      update_core_vcr_configuration
      update_core_models_dev_map if models_dev_provider
    end

    def generate_provider_gem
      write_template 'gem/gitignore.erb', '.gitignore'
      write_template 'gem/rspec.erb', '.rspec'
      write_template 'gem/rubocop.yml.erb', '.rubocop.yml'
      write_template 'gem/overcommit.yml.erb', '.overcommit.yml'
      write_template 'gem/flayignore.erb', '.flayignore'
      write_template 'gem/env.example.erb', '.env.example'
      write_template 'gem/appraisals.erb', 'Appraisals'
      write_template 'gem/gemfile.erb', 'Gemfile'
      write_template 'gem/rakefile.erb', 'Rakefile'
      write_template 'gem/archspec.rb.erb', 'Archspec.rb'
      write_template 'gem/readme.md.erb', 'README.md'
      write_template 'gem/license.erb', 'LICENSE'
      write_template 'gem/gemspec.erb', "#{gem_name}.gemspec"
      write_template 'gem/ci.yml.erb', '.github/workflows/ci.yml'
      write_template 'gem/release.yml.erb', '.github/workflows/release.yml'
      write_template 'gem/gitleaks.yml.erb', '.github/workflows/gitleaks.yml'
      write_template 'gem/bin/setup.erb', 'bin/setup', executable: true
      write_template 'gem/bin/console.erb', 'bin/console', executable: true
      write_template 'gem/entrypoint.rb.erb', "lib/ruby_llm/#{slug}.rb"
      write_template 'gem/version.rb.erb', "lib/ruby_llm/#{slug}/version.rb"
      write_template 'gem/provider.rb.erb', "lib/ruby_llm/providers/#{slug}.rb"
      write_template 'shared/capabilities.rb.erb', "lib/ruby_llm/providers/#{slug}/capabilities.rb"
      write_template 'gem/spec_helper.rb.erb', 'spec/spec_helper.rb'
      write_template 'gem/rubyllm_configuration.rb.erb', 'spec/support/rubyllm_configuration.rb'
      write_template 'gem/vcr_configuration.rb.erb', 'spec/support/vcr_configuration.rb'
      write_template 'gem/streaming_error_helpers.rb.erb', 'spec/support/streaming_error_helpers.rb'
      write_template 'gem/provider_spec.rb.erb', "spec/ruby_llm/providers/#{slug}_spec.rb"
      write_template 'shared/capabilities_spec.rb.erb', "spec/ruby_llm/providers/#{slug}/capabilities_spec.rb"
      write_template 'gem/chat_spec.rb.erb', 'spec/ruby_llm/chat_spec.rb'
      write_template 'gem/chat_streaming_spec.rb.erb', 'spec/ruby_llm/chat_streaming_spec.rb'
      write_template 'gem/models_spec.rb.erb', 'spec/ruby_llm/models_spec.rb'
      write_template 'gem/fixtures_gitkeep.erb', 'spec/fixtures/vcr_cassettes/.gitkeep'
    end

    def update_core_registration
      path = file_path('lib/ruby_llm.rb')
      insert_sorted_line(path, "  '#{slug}' => '#{class_name}',", /^\s+'[^']+' => '[^']+',?$/)
      insert_sorted_line(
        path,
        "RubyLLM::Provider.register :#{slug}, RubyLLM::Providers::#{class_name}",
        /^RubyLLM::Provider\.register /
      )
    end

    def update_core_env_example
      path = file_path('.env.example')
      return unless File.exist?(path)

      append_unique_line(path, "#{api_key_env}=$(op read \"op://RubyLLM/#{class_name}/credential\")")
      append_unique_line(path, "#{api_base_env}=#{api_base}")
    end

    def update_core_spec_configuration
      path = file_path('spec/support/rubyllm_configuration.rb')
      return unless File.exist?(path)

      insert_sorted_line(path, "      config.#{api_base_config} = ENV.fetch('#{api_base_env}', '#{api_base}')",
                         /^\s+config\.[a-z0-9_]+_api_base =/)
      insert_sorted_line(path, "      config.#{api_key_config} = ENV.fetch('#{api_key_env}', 'test')",
                         /^\s+config\.[a-z0-9_]+_api_key =/)
    end

    def update_core_vcr_configuration
      path = file_path('spec/support/vcr_configuration.rb')
      return unless File.exist?(path)

      line = "  config.filter_sensitive_data('<#{api_key_env}>') { " \
             "ENV.fetch('#{api_key_env}', nil) }"
      insert_sorted_line(path, line, /^\s+config\.filter_sensitive_data\('<[A-Z0-9_]+>'\)/)
    end

    def update_core_models_dev_map
      path = file_path('lib/ruby_llm/models.rb')
      return unless File.exist?(path)

      insert_before_first(path, "      '#{models_dev_provider}' => '#{slug}',", /^    \}\.freeze$/)
    end

    def write_template(template, relative_path, executable: false)
      content = ERB.new(File.read(template_path(template)), trim_mode: '-').result(binding)
      write_file(relative_path, content, executable:)
    end

    def write_file(relative_path, content, executable: false)
      path = file_path(relative_path)
      if File.exist?(path) && !@force
        @result.skipped << relative_path
        return
      end

      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
      FileUtils.chmod('+x', path) if executable
      @result.written << relative_path
    end

    def append_unique_line(path, line)
      content = File.exist?(path) ? File.read(path) : ''
      return @result.skipped << relative_path(path) if content.include?(line)

      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "#{content.chomp}\n#{line}\n")
      @result.updated << relative_path(path)
    end

    def insert_sorted_line(path, line, matcher)
      content = File.read(path)
      return @result.skipped << relative_path(path) if content.include?(line)

      lines = content.lines
      indexes = lines.each_index.select { |index| lines[index].match?(matcher) }
      insert_at = indexes.find { |index| line < lines[index].chomp } || indexes.last&.+(1) || lines.length
      lines.insert(insert_at, "#{line}\n")
      File.write(path, lines.join)
      @result.updated << relative_path(path)
    end

    def insert_before_first(path, line, matcher)
      content = File.read(path)
      return @result.skipped << relative_path(path) if content.include?(line)

      lines = content.lines
      insert_at = lines.index { |candidate| candidate.match?(matcher) } || lines.length
      lines.insert(insert_at, "#{line}\n")
      File.write(path, lines.join)
      @result.updated << relative_path(path)
    end

    def file_path(relative_path)
      File.join(destination, relative_path)
    end

    def relative_path(path)
      Pathname.new(path).relative_path_from(Pathname.new(destination)).to_s
    end

    def template_path(relative_path)
      File.join(TEMPLATE_ROOT, relative_path)
    end

    def normalize_option(value, allowed, name)
      normalized = value.to_s.tr('-', '_')
      return normalized if allowed.include?(normalized)

      raise ArgumentError, "unsupported #{name}: #{value.inspect}. Expected one of: #{allowed.join(', ')}"
    end

    def classify(value)
      words = value.to_s.tr('-', '_').split('_').reject(&:empty?)
      return value if value.match?(/\A[A-Z][A-Za-z0-9:]*\z/)

      words.map { |word| word[0].upcase + word[1..] }.join
    end

    def blank_to_nil(value)
      value = value.to_s.strip
      value.empty? ? nil : value
    end

    def truthy?(value)
      case value
      when true, 'true', '1', 1, 'yes', 'on' then true
      else false
      end
    end

    def dynamic_models_option?(options)
      return truthy?(options[:dynamic_models]) if options.key?(:dynamic_models)

      mode == 'gem'
    end
  end
end
