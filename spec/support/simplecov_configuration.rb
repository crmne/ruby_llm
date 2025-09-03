# frozen_string_literal: true

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
  add_filter 'acts_as_legacy.rb'

  enable_coverage :branch

  formatter SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::SimpleFormatter,
      (SimpleCov::Formatter::Codecov if ENV['CODECOV_TOKEN']),
      SimpleCov::Formatter::CoberturaFormatter
    ].compact
  )
end
