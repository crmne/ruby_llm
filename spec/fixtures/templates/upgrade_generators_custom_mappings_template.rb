# frozen_string_literal: true

gem 'ruby_llm', path: ENV['RUBYLLM_PATH'] || '../../../..'

after_bundle do
  ActiveSupport::Inflector.inflections { |inflect| inflect.acronym 'LLM' }
  append_to_file 'config/initializers/inflections.rb', <<~RUBY
    ActiveSupport::Inflector.inflections do |inflect|
      inflect.acronym "LLM"
    end
  RUBY
  file 'config/initializers/ruby_llm.rb', <<~RUBY
    RubyLLM.configure do |config|
      config.openai_api_key = ENV.fetch("OPENAI_API_KEY", "test")
    end
  RUBY
  file 'config/initializers/strong_migrations.rb', <<~RUBY
    require "strong_migrations"
  RUBY

  generate 'ruby_llm:upgrade',
           'chat:AI::Chat',
           'message:AI::Chat::Message',
           'model:AI::LLMModel',
           'tool_call:AI::Chat::ToolCall'
end
