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
      config.openai_api_key = ENV.fetch('OPENAI_API_KEY')
      config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY')
      config.gemini_api_key = ENV.fetch('GEMINI_API_KEY')
      config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY')
      config.max_retries = 50
    end
  end
end
