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
