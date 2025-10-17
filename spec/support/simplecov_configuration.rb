# frozen_string_literal: true

unless ENV['SKIP_COVERAGE']
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/vendor/'
    add_filter 'acts_as_legacy.rb'
    add_filter '/lib/generators/'

    enable_coverage :branch

    formatter SimpleCov::Formatter::MultiFormatter.new(
      [
        SimpleCov::Formatter::SimpleFormatter,
        (SimpleCov::Formatter::Codecov if ENV['CODECOV_TOKEN']),
        SimpleCov::Formatter::CoberturaFormatter
      ].compact
    )
  end
end
