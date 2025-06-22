# frozen_string_literal: true

require 'dotenv/load'
require 'simplecov'
require 'simplecov-cobertura'
require 'codecov'
require 'vcr'

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'

  enable_coverage :branch

  formatter SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::SimpleFormatter,
      (SimpleCov::Formatter::Codecov if ENV['CODECOV_TOKEN']),
      SimpleCov::Formatter::CoberturaFormatter
    ].compact
  )
end

require 'bundler/setup'

# Load the dummy Rails app
ENV['RAILS_ENV'] = 'test'
require_relative 'dummy/config/environment'

# Ensure database is properly set up
begin
  # Create database if it doesn't exist
  ActiveRecord::Tasks::DatabaseTasks.create_current
rescue ActiveRecord::DatabaseAlreadyExists
  # Database already exists, that's fine
end

# Explicitly run the dummy app migrations
dummy_migrations_path = File.expand_path('dummy/db/migrate', __dir__)
ActiveRecord::MigrationContext.new(dummy_migrations_path).migrate

require 'fileutils'
require 'ruby_llm'
require 'webmock/rspec'

# VCR Configuration
VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Don't record new HTTP interactions when running in CI
  config.default_cassette_options = {
    record: ENV['CI'] ? :none : :new_episodes
  }

  # Create new cassette directory if it doesn't exist
  FileUtils.mkdir_p(config.cassette_library_dir)

  # Allow HTTP connections when necessary - this will fail PRs by design if they don't have cassettes
  config.allow_http_connections_when_no_cassette = true

  # Filter out API keys from the recorded cassettes
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV.fetch('OPENAI_API_KEY', nil) }
  config.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV.fetch('ANTHROPIC_API_KEY', nil) }
  config.filter_sensitive_data('<GEMINI_API_KEY>') { ENV.fetch('GEMINI_API_KEY', nil) }
  config.filter_sensitive_data('<DEEPSEEK_API_KEY>') { ENV.fetch('DEEPSEEK_API_KEY', nil) }
  config.filter_sensitive_data('<OPENROUTER_API_KEY>') { ENV.fetch('OPENROUTER_API_KEY', nil) }
  config.filter_sensitive_data('<OLLAMA_API_BASE>') { ENV.fetch('OLLAMA_API_BASE', 'http://localhost:11434/v1') }

  config.filter_sensitive_data('<AWS_ACCESS_KEY_ID>') { ENV.fetch('AWS_ACCESS_KEY_ID', nil) }
  config.filter_sensitive_data('<AWS_SECRET_ACCESS_KEY>') { ENV.fetch('AWS_SECRET_ACCESS_KEY', nil) }
  config.filter_sensitive_data('<AWS_REGION>') { ENV.fetch('AWS_REGION', 'us-west-2') }
  config.filter_sensitive_data('<AWS_SESSION_TOKEN>') { ENV.fetch('AWS_SESSION_TOKEN', nil) }

  config.filter_sensitive_data('<OPENAI_ORGANIZATION>') do |interaction|
    interaction.response.headers['Openai-Organization']&.first
  end
  config.filter_sensitive_data('<X_REQUEST_ID>') { |interaction| interaction.response.headers['X-Request-Id']&.first }
  config.filter_sensitive_data('<REQUEST_ID>') { |interaction| interaction.response.headers['Request-Id']&.first }
  config.filter_sensitive_data('<CF_RAY>') { |interaction| interaction.response.headers['Cf-Ray']&.first }

  # Filter cookies
  config.before_record do |interaction|
    if interaction.response.headers['Set-Cookie']
      interaction.response.headers['Set-Cookie'] = interaction.response.headers['Set-Cookie'].map { '<COOKIE>' }
    end
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around do |example|
    cassette_name = example.full_description.parameterize(separator: '_').delete_prefix('rubyllm_')
    VCR.use_cassette(cassette_name) do
      example.run
    end
  end
end

RSpec.shared_context 'with configured RubyLLM' do
  before do
    RubyLLM.configure do |config|
      config.openai_api_key = ENV.fetch('OPENAI_API_KEY', 'test')
      config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', 'test')
      config.gemini_api_key = ENV.fetch('GEMINI_API_KEY', 'test')
      config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY', 'test')
      config.openrouter_api_key = ENV.fetch('OPENROUTER_API_KEY', 'test')
      config.ollama_api_base = ENV.fetch('OLLAMA_API_BASE', 'http://localhost:11434/v1')

      config.bedrock_api_key = ENV.fetch('AWS_ACCESS_KEY_ID', 'test')
      config.bedrock_secret_key = ENV.fetch('AWS_SECRET_ACCESS_KEY', 'test')
      config.bedrock_region = 'us-west-2'
      config.bedrock_session_token = ENV.fetch('AWS_SESSION_TOKEN', nil)

      config.request_timeout = 240
      config.max_retries = 10
      config.retry_interval = 1
      config.retry_backoff_factor = 3
      config.retry_interval_randomness = 0.5
    end
  end
end

CHAT_MODELS = [
  { provider: :anthropic, model: 'claude-3-5-haiku-20241022' },
  { provider: :bedrock, model: 'anthropic.claude-3-5-haiku-20241022-v1:0' },
  { provider: :gemini, model: 'gemini-2.0-flash' },
  { provider: :deepseek, model: 'deepseek-chat' },
  { provider: :openai, model: 'gpt-4.1-nano' },
  { provider: :openrouter, model: 'anthropic/claude-3.5-haiku' },
  { provider: :ollama, model: 'qwen3' }
].freeze

PDF_MODELS = [
  { provider: :anthropic, model: 'claude-3-5-haiku-20241022' },
  { provider: :gemini, model: 'gemini-2.0-flash' },
  { provider: :openai, model: 'gpt-4.1-nano' },
  { provider: :openrouter, model: 'google/gemini-2.5-flash-preview' }
].freeze

VISION_MODELS = [
  { provider: :anthropic, model: 'claude-3-5-haiku-20241022' },
  { provider: :bedrock, model: 'anthropic.claude-3-5-sonnet-20241022-v2:0' },
  { provider: :gemini, model: 'gemini-2.0-flash' },
  { provider: :openai, model: 'gpt-4.1-nano' },
  { provider: :openrouter, model: 'anthropic/claude-3.5-haiku' },
  { provider: :ollama, model: 'qwen3' }
].freeze

AUDIO_MODELS = [
  { provider: :openai, model: 'gpt-4o-mini-audio-preview' }
].freeze
