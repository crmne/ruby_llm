# frozen_string_literal: true

gem 'ruby_llm', path: ENV['RUBYLLM_PATH'] || '../../../..'

after_bundle do
  file 'config/initializers/ruby_llm.rb', <<~RUBY
    RubyLLM.configure do |config|
      config.openai_api_key = ENV.fetch("OPENAI_API_KEY", "test")
    end
  RUBY
  file 'config/initializers/strong_migrations.rb', <<~RUBY
    require "strong_migrations"
    StrongMigrations.skip_database(:primary)
  RUBY

  generate 'ruby_llm:upgrade'
end
