# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require_relative 'spec_helper'
require_relative 'dummy/config/application'
require 'ruby_llm/railtie'

Rails.application.initialize! unless Rails.application.initialized?

# Rebuilds the dummy app's test database from its schema.
module DummyDatabase
  def self.rebuild
    begin
      # Drop and recreate the database to avoid foreign key constraint issues.
      ActiveRecord::Tasks::DatabaseTasks.drop_current
    rescue StandardError
      nil
    end
    ActiveRecord::Tasks::DatabaseTasks.create_current
    ActiveRecord::Tasks::DatabaseTasks.load_schema_current

    RubyLLM.models.load_from_json
    RubyLLM::ActiveRecord::Model.save_to_database
    @built_by = Process.pid
  end

  # A process forked after this file loaded, such as a mutineer worker,
  # inherits a database file that earlier forks have written to. Test-queue
  # workers are forks too, but share one database, so they keep the build.
  def self.stale?
    @built_by != Process.pid && !defined?(TestQueue)
  end
end

DummyDatabase.rebuild

RSpec.configure do |config|
  config.before(:suite) { DummyDatabase.rebuild if DummyDatabase.stale? }
end
