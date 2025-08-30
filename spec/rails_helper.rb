# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require_relative 'spec_helper'
require_relative 'dummy/config/application'
require 'ruby_llm/railtie'

Rails.application.initialize! unless Rails.application.initialized?

# Drop and recreate database to avoid foreign key constraint issues
begin
  ActiveRecord::Tasks::DatabaseTasks.drop_current
rescue StandardError
  nil
end
ActiveRecord::Tasks::DatabaseTasks.create_current
ActiveRecord::Tasks::DatabaseTasks.load_schema_current

RubyLLM.models.load_from_json!
Model.save_to_database
