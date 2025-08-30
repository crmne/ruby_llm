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

# Load schema instead of running migrations (faster and more reliable for tests)
ActiveRecord::Tasks::DatabaseTasks.load_schema_current

require 'fileutils'
require 'ruby_llm'
require 'webmock/rspec'
require_relative 'support/database_setup'
require_relative 'support/streaming_error_helpers'

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
  config.filter_sensitive_data('<PERPLEXITY_API_KEY>') { ENV.fetch('PERPLEXITY_API_KEY', nil) }
  config.filter_sensitive_data('<OPENROUTER_API_KEY>') { ENV.fetch('OPENROUTER_API_KEY', nil) }
  config.filter_sensitive_data('<MISTRAL_API_KEY>') { ENV.fetch('MISTRAL_API_KEY', nil) }
  config.filter_sensitive_data('<OLLAMA_API_BASE>') { ENV.fetch('OLLAMA_API_BASE', 'http://localhost:11434/v1') }

  config.filter_sensitive_data('<GPUSTACK_API_BASE>') { ENV.fetch('GPUSTACK_API_BASE', 'http://localhost:11444/v1') }
  config.filter_sensitive_data('<GPUSTACK_API_KEY>') { ENV.fetch('GPUSTACK_API_KEY', nil) }

  config.filter_sensitive_data('<AWS_ACCESS_KEY_ID>') { ENV.fetch('AWS_ACCESS_KEY_ID', nil) }
  config.filter_sensitive_data('<AWS_SECRET_ACCESS_KEY>') { ENV.fetch('AWS_SECRET_ACCESS_KEY', nil) }
  config.filter_sensitive_data('<AWS_REGION>') { ENV.fetch('AWS_REGION', 'us-west-2') }
  config.filter_sensitive_data('<AWS_SESSION_TOKEN>') { ENV.fetch('AWS_SESSION_TOKEN', nil) }

  config.filter_sensitive_data('<GOOGLE_CLOUD_PROJECT>') { ENV.fetch('GOOGLE_CLOUD_PROJECT', 'test-project') }
  config.filter_sensitive_data('<GOOGLE_CLOUD_LOCATION>') { ENV.fetch('GOOGLE_CLOUD_LOCATION', 'us-central1') }

  # Filter Google OAuth tokens and credentials
  config.filter_sensitive_data('<GOOGLE_REFRESH_TOKEN>') do |interaction|
    interaction.request.body[/refresh_token=([^&]+)/, 1] if interaction.request.body&.include?('refresh_token')
  end

  config.filter_sensitive_data('<GOOGLE_CLIENT_ID>') do |interaction|
    interaction.request.body[/client_id=([^&]+)/, 1] if interaction.request.body&.include?('client_id')
  end

  config.filter_sensitive_data('<GOOGLE_CLIENT_SECRET>') do |interaction|
    interaction.request.body[/client_secret=([^&]+)/, 1] if interaction.request.body&.include?('client_secret')
  end

  config.filter_sensitive_data('<GOOGLE_ACCESS_TOKEN>') do |interaction|
    if interaction.response.body&.include?('"access_token"')
      begin
        JSON.parse(interaction.response.body)['access_token']
      rescue JSON::ParserError
        nil
      end
    end
  end

  config.filter_sensitive_data('<GOOGLE_ID_TOKEN>') do |interaction|
    if interaction.response.body&.include?('"id_token"')
      begin
        JSON.parse(interaction.response.body)['id_token']
      rescue JSON::ParserError
        nil
      end
    end
  end

  # Filter Bearer tokens in Authorization headers for Vertex AI
  config.filter_sensitive_data('Bearer <GOOGLE_BEARER_TOKEN>') do |interaction|
    auth_header = interaction.request.headers['Authorization']&.first
    auth_header if auth_header&.start_with?('Bearer ya29.')
  end

  config.filter_sensitive_data('<OPENAI_ORGANIZATION>') do |interaction|
    interaction.response.headers['Openai-Organization']&.first
  end
  config.filter_sensitive_data('<ANTHROPIC_ORGANIZATION_ID>') do |interaction|
    interaction.response.headers['Anthropic-Organization-Id']&.first
  end
  config.filter_sensitive_data('<X_REQUEST_ID>') { |interaction| interaction.response.headers['X-Request-Id']&.first }
  config.filter_sensitive_data('<REQUEST_ID>') { |interaction| interaction.response.headers['Request-Id']&.first }
  config.filter_sensitive_data('<CF_RAY>') { |interaction| interaction.response.headers['Cf-Ray']&.first }

  # Filter large strings used to test "context length exceeded" error handling
  config.filter_sensitive_data('<MASSIVE_TEXT>') { 'a' * 1_000_000 }

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
      config.perplexity_api_key = ENV.fetch('PERPLEXITY_API_KEY', 'test')
      config.openrouter_api_key = ENV.fetch('OPENROUTER_API_KEY', 'test')
      config.mistral_api_key = ENV.fetch('MISTRAL_API_KEY', 'test')
      config.ollama_api_base = ENV.fetch('OLLAMA_API_BASE', 'http://localhost:11434/v1')

      config.gpustack_api_base = ENV.fetch('GPUSTACK_API_BASE', 'http://localhost:11444/v1')
      config.gpustack_api_key = ENV.fetch('GPUSTACK_API_KEY', nil)

      config.bedrock_api_key = ENV.fetch('AWS_ACCESS_KEY_ID', 'test')
      config.bedrock_secret_key = ENV.fetch('AWS_SECRET_ACCESS_KEY', 'test')
      config.bedrock_region = 'us-west-2'
      config.bedrock_session_token = ENV.fetch('AWS_SESSION_TOKEN', nil)

      config.vertexai_project_id = ENV.fetch('GOOGLE_CLOUD_PROJECT', 'test-project')
      config.vertexai_location = ENV.fetch('GOOGLE_CLOUD_LOCATION', 'us-central1')

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
  { provider: :deepseek, model: 'deepseek-chat' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :gpustack, model: 'qwen3' },
  { provider: :mistral, model: 'mistral-small-latest' },
  { provider: :ollama, model: 'qwen3' },
  { provider: :openai, model: 'gpt-4.1-nano' },
  { provider: :openrouter, model: 'anthropic/claude-3.5-haiku' },
  { provider: :perplexity, model: 'sonar' },
  { provider: :vertexai, model: 'gemini-2.5-flash' }
].freeze

PDF_MODELS = [
  { provider: :anthropic, model: 'claude-3-5-haiku-20241022' },
  { provider: :bedrock, model: 'us.anthropic.claude-3-7-sonnet-20250219-v1:0' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :openai, model: 'gpt-4.1-nano' },
  { provider: :openrouter, model: 'google/gemini-2.5-flash' },
  { provider: :vertexai, model: 'gemini-2.5-flash' }
].freeze

VISION_MODELS = [
  { provider: :anthropic, model: 'claude-3-5-haiku-20241022' },
  { provider: :bedrock, model: 'anthropic.claude-3-5-sonnet-20241022-v2:0' },
  { provider: :gemini, model: 'gemini-2.5-flash' },
  { provider: :mistral, model: 'pixtral-12b-latest' },
  { provider: :ollama, model: 'granite3.2-vision' },
  { provider: :openai, model: 'gpt-4.1-nano' },
  { provider: :openrouter, model: 'anthropic/claude-3.5-haiku' },
  { provider: :vertexai, model: 'gemini-2.5-flash' }
].freeze

AUDIO_MODELS = [
  { provider: :openai, model: 'gpt-4o-mini-audio-preview' }
].freeze

EMBEDDING_MODELS = [
  { provider: :gemini, model: 'text-embedding-004' },
  { provider: :openai, model: 'text-embedding-3-small' },
  { provider: :mistral, model: 'mistral-embed' },
  { provider: :vertexai, model: 'text-embedding-004' }
].freeze

IMAGE_CHAT_MODELS = [
  { provider: :gemini, model: 'gemini-2.0-flash-preview-image-generation' }
].freeze

def save_and_verify_image(image)
  # Create a temp file to save to
  temp_file = Tempfile.new(['image', '.png'])
  temp_path = temp_file.path
  temp_file.close

  begin
    saved_path = image.save(temp_path)
    expect(saved_path).to eq(temp_path)
    expect(File.exist?(temp_path)).to be true

    file_size = File.size(temp_path)
    expect(file_size).to be > 1000 # Any real image should be larger than 1KB
  ensure
    # Clean up
    File.delete(temp_path)
  end
end
