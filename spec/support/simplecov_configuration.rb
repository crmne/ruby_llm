# frozen_string_literal: true

unless ENV['SKIP_COVERAGE']
  # Undercover depends on rugged, a C extension, so it is installed on MRI only.
  require 'undercover/simplecov_formatter' if RUBY_ENGINE == 'ruby'

  SimpleCov.start do
    track_files 'lib/**/*.rb'

    add_filter '/spec/'
    add_filter '/vendor/'
    add_filter '/lib/generators/'
    # Rake tasks are maintainer tooling and are not in spec.files, so they
    # would otherwise be scored as if they shipped. Specs that load one still
    # run; only the report ignores it.
    add_filter '/tasks/'

    enable_coverage :branch

    formatter SimpleCov::Formatter::MultiFormatter.new(
      [
        SimpleCov::Formatter::SimpleFormatter,
        SimpleCov::Formatter::CoberturaFormatter,
        (SimpleCov::Formatter::Undercover if defined?(SimpleCov::Formatter::Undercover))
      ].compact
    )
  end
end
