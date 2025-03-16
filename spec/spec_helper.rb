# frozen_string_literal: true

require 'simplecov'
require 'simplecov-cobertura'
require 'codecov'

SimpleCov.start do
  enable_coverage :branch

  formatter SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::SimpleFormatter,
      SimpleCov::Formatter::Codecov,
      SimpleCov::Formatter::CoberturaFormatter
    ]
  )
end

require 'active_record'
require 'bundler/setup'
require 'fileutils'
require 'ruby_llm'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

RSpec.shared_context 'with configured RubyLLM' do
  before do
    RubyLLM.configure do |config|
      # Make other API keys optional when focusing on OpenRouter
      config.openai_api_key = ENV['OPENAI_API_KEY']
      config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
      config.gemini_api_key = ENV['GEMINI_API_KEY']
      config.deepseek_api_key = ENV['DEEPSEEK_API_KEY']
      # Only OpenRouter is required
      config.open_router_api_key = ENV.fetch('OPENROUTER_API_KEY')
      config.max_retries = 50
    end
  end
end
