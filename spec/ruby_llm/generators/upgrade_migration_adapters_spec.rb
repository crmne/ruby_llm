# frozen_string_literal: true

require 'spec_helper'
require 'active_record'
require 'active_support/core_ext/string/inflections'
require 'erb'

if ENV['RUBY_LLM_POSTGRES_URL'] || ENV['RUBY_LLM_MYSQL_URL']
  require 'strong_migrations'
  StrongMigrations.lock_timeout = 10.seconds
  StrongMigrations.statement_timeout = 1.hour
end

class UpgradeMigrationTemplateContext
  attr_reader :adapter

  def initialize(adapter)
    @adapter = adapter
  end

  def migration_version = '[8.1]'
  def reference_type = 'bigint'
  def chat_table_name = 'chats'
  def message_table_name = 'messages'
  def chat_model_name = 'Chat'
  def message_model_name = 'Message'
  def legacy_model_table_name = 'models'
  def legacy_tool_call_table_name = 'tool_calls'
  def legacy_batch_table_name = 'batches'
  def legacy_model_foreign_key = 'model_id'
  def legacy_tool_call_message_foreign_key = 'message_id'
  def legacy_message_tool_call_foreign_key = 'tool_call_id'
  def legacy_batch_explicit? = false
  def postgresql? = adapter == 'postgresql'
  def mysql? = adapter == 'mysql2'

  def create_migration_class_name(table_name)
    "Create#{table_name.camelize}"
  end

  def usage_operations_sql
    sql_list(%w[chat embedding moderation image speech transcription ocr rerank])
  end

  def usage_statuses_sql
    sql_list(%w[pending succeeded failed cancelled])
  end

  def render(path)
    ERB.new(File.read(path), trim_mode: '-').result(binding)
  end

  private

  def sql_list(values)
    values.map { |value| "'#{value}'" }.join(', ')
  end
end

RSpec.describe 'RubyLLM upgrade migration adapters', :generator do # rubocop:disable RSpec/DescribeClass
  external_adapter = ENV.fetch('RUBY_LLM_POSTGRES_URL', nil) || ENV.fetch('RUBY_LLM_MYSQL_URL', nil)
  databases = {
    postgresql: ['postgresql', ENV.fetch('RUBY_LLM_POSTGRES_URL', nil)],
    mysql: ['mysql2', ENV.fetch('RUBY_LLM_MYSQL_URL', nil)],
    sqlite: ['sqlite3', external_adapter ? nil : { adapter: 'sqlite3', database: ':memory:' }]
  }

  databases.each do |name, (adapter, url)|
    next unless url

    context "with #{name}" do
      before do
        ActiveRecord::Base.establish_connection(url)
        ActiveRecord::Migration.verbose = false
        drop_test_tables
      end

      after do
        drop_test_tables
        restore_test_connection
      end

      def restore_test_connection
        return unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application

        dummy_config = Rails.application.config.database_configuration['test']
        ActiveRecord::Base.establish_connection(dummy_config)
      end

      it 'rejects an incompatible application schema before changing it' do
        create_legacy_schema
        connection.remove_column(:messages, :content)
        migration = load_upgrade_migration(adapter)

        expect { migration.new.migrate(:up) }
          .to raise_error(RuntimeError, 'messages has content_raw but no content column to receive it')
        expect(connection.column_exists?(:chats, :cancelled)).to be(false)
        expect(connection.table_exists?(:models)).to be(true)
        expect(connection.table_exists?(:ruby_llm_models)).to be(false)
      end

      it 'upgrades legacy records to the clean schema contract' do
        if external_adapter
          expect(ActiveRecord::Migration.ancestors).to include(StrongMigrations::Migration)

          connection.create_table(:strong_migrations_probe)
          unsafe_migration = Class.new(ActiveRecord::Migration[8.1]) do
            define_method(:change) { rename_table :strong_migrations_probe, :renamed_probe }
          end
          expect { unsafe_migration.new.migrate(:up) }.to raise_error(StrongMigrations::UnsafeMigration)
        end

        create_legacy_schema
        insert_legacy_records(adapter)
        migration = load_upgrade_migration(adapter)
        statements = []
        subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
          statements << payload[:sql]
        end
        begin
          migration.new.migrate(:up)
        ensure
          ActiveSupport::Notifications.unsubscribe(subscription)
        end

        usage = connection.select_one('SELECT * FROM ruby_llm_usages')
        message = connection.select_one('SELECT * FROM messages')
        expect(usage).to include(
          'provider' => 'openai',
          'model' => 'gpt-adapter-test',
          'operation' => 'chat',
          'status' => 'succeeded'
        )
        expect(usage['input_tokens'].to_i).to eq(12)
        expect(usage['total_cost'].to_f).to be_within(0.000_000_001).of(0.003)
        expect(JSON.parse(message['content'])).to eq('answer' => 42)
        expect(connection.table_exists?(:ruby_llm_models)).to be(true)
        expect(connection.table_exists?(:ruby_llm_tool_calls)).to be(true)
        expect(connection.table_exists?(:ruby_llm_batches)).to be(true)
        if adapter == 'mysql2'
          usage_index_alter = statements.find do |sql|
            sql.match?(/ALTER TABLE [`"]?ruby_llm_usages/i) && sql.scan(/\bADD\b.*?\bINDEX\b/i).size == 3
          end
          tool_call_index_alter = statements.find do |sql|
            sql.match?(/ALTER TABLE [`"]?ruby_llm_tool_calls/i) && sql.scan(/\bADD\b.*?\bINDEX\b/i).size == 4
          end
          expect(usage_index_alter).not_to be_nil
          expect(tool_call_index_alter).not_to be_nil
          expect(statements.grep(/FOREIGN_KEY_CHECKS\s*=\s*0/i)).not_to be_empty
        end

        upgraded_contract = internal_schema_contract
        drop_test_tables
        create_clean_schema(adapter)
        expect(internal_schema_contract).to eq(upgraded_contract)
      end
    end
  end

  def connection
    ActiveRecord::Base.connection
  end

  def drop_test_tables
    %i[
      ruby_llm_v2_usage_backfill ruby_llm_usages ruby_llm_tool_calls tool_calls messages chats
      ruby_llm_batches batches ruby_llm_models models renamed_probe strong_migrations_probe
    ].each do |table|
      connection.drop_table(table, force: :cascade) if connection.table_exists?(table)
    end
  end

  def create_legacy_schema
    ActiveRecord::Schema.define do
      create_table :models do |table|
        table.string :model_id, null: false
        table.string :name, null: false
        table.string :provider, null: false
        table.json :modalities
        table.json :capabilities
        table.json :pricing
        table.json :metadata
        table.timestamps
      end
      add_index :models, %i[provider model_id]

      create_table :chats do |table|
        table.bigint :model_id
        table.timestamps
      end

      create_table :messages do |table|
        table.bigint :chat_id, null: false
        table.bigint :model_id
        table.bigint :tool_call_id
        table.string :role, null: false
        table.text :content
        table.json :content_raw
        table.integer :input_tokens
        table.integer :output_tokens
        table.decimal :total_cost, precision: 16, scale: 10
        table.json :cost_details
        table.timestamps
      end

      create_table :tool_calls do |table|
        table.bigint :message_id, null: false
        table.string :tool_call_id, null: false
        table.string :name, null: false
        table.json :arguments
        table.timestamps
      end
      add_index :tool_calls, :tool_call_id

      create_table :batches do |table|
        table.string :provider_batch_id, null: false
        table.string :provider, null: false
        table.string :status
        table.boolean :completed, null: false, default: false
        table.json :chat_ids
        table.timestamps
      end
      add_index :batches, %i[provider provider_batch_id]
    end
  end

  def insert_legacy_records(adapter)
    now = connection.quote(Time.now.utc)
    json = lambda do |value|
      quoted = connection.quote(value.to_json)
      adapter == 'postgresql' ? "#{quoted}::json" : quoted
    end
    connection.execute <<~SQL
      INSERT INTO models
        (id, model_id, name, provider, modalities, capabilities, pricing, metadata, created_at, updated_at)
      VALUES
        (1, 'gpt-adapter-test', 'Adapter Test', 'openai', #{json.call({})}, #{json.call([])},
         #{json.call({})}, #{json.call({})}, #{now}, #{now})
    SQL
    connection.execute <<~SQL
      INSERT INTO chats (id, model_id, created_at, updated_at)
      VALUES (1, 1, #{now}, #{now})
    SQL
    connection.execute <<~SQL
      INSERT INTO messages
        (id, chat_id, model_id, role, content_raw, input_tokens, output_tokens,
         total_cost, cost_details, created_at, updated_at)
      VALUES
        (1, 1, 1, 'assistant', #{json.call(answer: 42)}, 12, 3, 0.003,
         #{json.call(input: 0.001, output: 0.002, total: 0.003)}, #{now}, #{now})
    SQL
    connection.execute <<~SQL
      INSERT INTO tool_calls
        (id, message_id, tool_call_id, name, arguments, created_at, updated_at)
      VALUES
        (1, 1, 'call-adapter-test', 'calculator', #{json.call(expression: '6 * 7')}, #{now}, #{now})
    SQL
    connection.execute <<~SQL
      INSERT INTO batches
        (id, provider_batch_id, provider, status, completed, chat_ids, created_at, updated_at)
      VALUES
        (1, 'batch-adapter-test', 'openai', 'completed', #{adapter == 'postgresql' ? 'TRUE' : '1'},
         #{json.call([1])}, #{now}, #{now})
    SQL
  end

  def load_upgrade_migration(adapter)
    template = File.expand_path(
      '../../../lib/generators/ruby_llm/upgrade/templates/add_v2_0_message_columns.rb.tt',
      __dir__
    )
    source = UpgradeMigrationTemplateContext.new(adapter).render(template)
    scope = Module.new
    scope.module_eval(source, template)
    scope.const_get(:AddRubyLlmV20Columns)
  end

  def create_clean_schema(adapter)
    context = UpgradeMigrationTemplateContext.new(adapter)
    templates = %w[
      create_ruby_llm_records_migration.rb.tt create_chats_migration.rb.tt create_messages_migration.rb.tt
    ]
    scope = Module.new
    templates.each do |filename|
      template = File.expand_path("../../../lib/generators/ruby_llm/install/templates/#{filename}", __dir__)
      scope.module_eval(context.render(template), template)
    end
    %i[CreateRubyLlmRecords CreateChats CreateMessages].each do |name|
      scope.const_get(name).new.migrate(:up)
    end
  end

  def internal_schema_contract
    %i[ruby_llm_models ruby_llm_tool_calls ruby_llm_usages ruby_llm_batches].to_h do |table|
      columns = connection.columns(table).map do |column|
        [
          column.name, column.type, schema_sql_type(column), column.null, column.default,
          column.limit, column.precision, column.scale
        ]
      end.sort_by(&:first)
      indexes = connection.indexes(table).map do |index|
        [index.columns, index.unique, index.using.to_s]
      end.sort_by(&:to_s)
      constraints = connection.check_constraints(table).map(&:expression).sort
      [table, { primary_key: connection.primary_key(table), columns: columns, indexes: indexes,
                constraints: constraints }]
    end
  end

  def schema_sql_type(column)
    return column.type.to_s if connection.adapter_name == 'SQLite'

    column.sql_type
  end
end
