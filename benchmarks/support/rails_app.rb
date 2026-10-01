# frozen_string_literal: true

require_relative 'harness'
require_relative 'canned_adapter'
require_relative 'payloads'

module Benchmarks
  # Boots the dummy application of the checkout under test, with a SQLite
  # database and an Active Storage disk service of its own under
  # tmp/benchmark, and RubyLLM answering through the canned adapter.
  module RailsApp
    module_function

    # +fresh+ starts from an empty database and storage; otherwise the app
    # opens what an earlier process left.
    def boot(database:, fresh: true, automatic_scope_inversing: nil)
      path = File.join(Benchmarks.scratch('rails'), database)
      FileUtils.rm_rf(Dir["#{path}.sqlite3*"] + ["#{path}-storage"]) if fresh
      ENV['RAILS_ENV'] = 'test'
      ENV['DATABASE_URL'] = "sqlite3:#{path}.sqlite3"
      require File.join(ROOT, 'spec/dummy/config/application')
      configure(Rails.application.config, "#{path}-storage", automatic_scope_inversing)
      require 'ruby_llm/railtie'
      Rails.application.initialize!
      ActiveRecord::Base.logger = nil
      load_schema if fresh
      Benchmarks.configure(faraday_adapter: CannedAdapter, openai_api_key: 'test', anthropic_api_key: 'test')
    end

    def configure(config, storage, automatic_scope_inversing)
      config.eager_load = false
      config.active_job.queue_adapter = :inline
      config.active_storage.service_configurations = { 'test' => { 'service' => 'Disk', 'root' => storage } }
      config.active_record.automatic_scope_inversing = automatic_scope_inversing unless automatic_scope_inversing.nil?
    end

    def load_schema
      ActiveRecord::Migration.verbose = false
      ActiveRecord::Tasks::DatabaseTasks.load_schema_current
      RubyLLM.models.load_from_json
      RubyLLM::ActiveRecord::Model.save_to_database
    end

    # Returns a lambda that deletes the messages and usage rows created after
    # this call, so every measured ask finds the same transcript.
    def forget_new_rows
      last_message = Message.maximum(:id)
      last_usage = RubyLLM::ActiveRecord::Usage.maximum(:id)
      lambda do
        RubyLLM::ActiveRecord::Usage.where('id > ?', last_usage).delete_all
        Message.where('id > ?', last_message).delete_all
      end
    end

    # The SQL statements the block sends, leaving out schema lookups,
    # transaction control, and the query cache.
    def queries
      count = 0
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        count += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name])
      end
      yield
      count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    def downloads
      count = 0
      subscriber = ActiveSupport::Notifications.subscribe(/\Aservice_(streaming_)?download\.active_storage\z/) do
        count += 1
      end
      yield
      count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end
end
