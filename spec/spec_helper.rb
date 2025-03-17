# frozen_string_literal: true

require 'simplecov'
require 'simplecov-cobertura'
require 'codecov'

SimpleCov.start do
  enable_coverage :branch

  formatter SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::SimpleFormatter,
      (SimpleCov::Formatter::Codecov unless ENV['SKIP_CODECOV_UPLOAD']),
      SimpleCov::Formatter::CoberturaFormatter
    ].compact
  )
end

require 'active_record'
require 'bundler/setup'
require 'fileutils'
require 'ruby_llm'

require 'vcr'
require 'webmock/rspec'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false

  # Filter sensitive request headers
  config.filter_sensitive_data('<AUTHORIZATION>') { |interaction| interaction.request.headers['Authorization']&.first }
  config.filter_sensitive_data('<X_GOOG_API_KEY>') do |interaction|
    interaction.request.headers['X-Goog-Api-Key']&.first
  end

  # Filter sensitive response headers
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

  vcr_record = ENV.fetch('VCR_RECORD', 'all').to_sym
  config.around do |example|
    cassette_name = example.full_description.parameterize(separator: '_')
    VCR.use_cassette(cassette_name, record: vcr_record) do
      example.run
    end
  end
end

RSpec.shared_context 'with configured RubyLLM' do
  before do
    RubyLLM.configure do |config|
      config.openai_api_key = ENV.fetch('OPENAI_API_KEY')
      config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY')
      config.gemini_api_key = ENV.fetch('GEMINI_API_KEY')
      config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY')
      config.max_retries = 50
    end
  end
end
