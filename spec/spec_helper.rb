# frozen_string_literal: true

require "simplecov"
require "simplecov-cobertura"
require "codecov"
require "ruby_llm"

SimpleCov.start do
  enable_coverage :branch

  formatter SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::SimpleFormatter,
      SimpleCov::Formatter::Codecov,
      SimpleCov::Formatter::CoberturaFormatter,
    ]
  )
end

require "active_record"
require "bundler/setup"
require "fileutils"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around do |example|
    cassette_name = example.full_description.parameterize(separator: "_").delete_prefix("rubyllm_")
    cassette_name = example.full_description.parameterize(separator: "_").delete_prefix("rubyllm_")
    VCR.use_cassette(cassette_name) do
      example.run
    end
  end
end

RSpec.shared_context "with configured RubyLLM" do
RSpec.shared_context "with configured RubyLLM" do
  before do
    RubyLLM.configure do |config|
      config.openai_api_key = ENV.fetch("OPENAI_API_KEY", "dummy-openai-key")
      config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", "dummy-anthropic-key")
      config.gemini_api_key = ENV.fetch("GEMINI_API_KEY", "dummy-gemini-key")
      config.deepseek_api_key = ENV.fetch("DEEPSEEK_API_KEY", "dummy-deepseek-key")
      config.mistral_api_key = ENV.fetch("MISTRAL_API_KEY", "dummy-mistral-key")
      config.openai_api_key = ENV.fetch("OPENAI_API_KEY", "dummy-openai-key")
      config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", "dummy-anthropic-key")
      config.gemini_api_key = ENV.fetch("GEMINI_API_KEY", "dummy-gemini-key")
      config.deepseek_api_key = ENV.fetch("DEEPSEEK_API_KEY", "dummy-deepseek-key")
      config.mistral_api_key = ENV.fetch("MISTRAL_API_KEY", "dummy-mistral-key")
      config.max_retries = 50
    end
  end
end
