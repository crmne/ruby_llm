# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development do # rubocop:disable Metrics/BlockLength
  gem 'appraisal'
  gem 'archspec' if RUBY_ENGINE == 'ruby' && Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.2')
  gem 'async', '>= 2.0', platform: :mri
  gem 'avro'
  gem 'bundler', '>= 2.0'
  gem 'colorize'
  gem 'dotenv'
  gem 'ferrum'
  gem 'flay'
  gem 'image_processing', '~> 1.2'
  gem 'irb'
  # Older Rails versions need JSON 2; the Rails 8.1 appraisal also tests JSON 3.
  gem 'json', '< 3'
  gem 'json_schemer'
  gem 'nokogiri'
  gem 'overcommit', '>= 0.66'
  gem 'pry', '>= 0.14'
  gem 'rails'
  gem 'rake', '>= 13.0'
  gem 'rdoc', '< 8', platform: 'jruby'
  gem 'reline'
  gem 'rspec', '~> 3.12'
  gem 'rubocop', '>= 1.0'
  gem 'rubocop-performance'
  gem 'rubocop-rake', '>= 0.6'
  gem 'rubocop-rspec'
  gem 'simplecov', '>= 0.21', '< 1.0'
  gem 'simplecov-cobertura'
  gem 'test-queue'

  # database drivers for MRI and JRuby
  gem 'activerecord-jdbcsqlite3-adapter', platform: 'jruby'
  gem 'jdbc-sqlite3', platform: 'jruby'
  gem 'sqlite3', platform: 'mri'

  gem 'vcr'
  gem 'webmock', '~> 3.18'
  gem 'websocket-driver'

  # Optional dependency for Vertex AI
  gem 'googleauth'
  gem 'google-cloud-storage'

  # Optional dependency for Bedrock
  gem 'aws-eventstream'
  gem 'aws-sdk-s3'
end

group :development, :test do
  gem 'turbo-rails'
end
