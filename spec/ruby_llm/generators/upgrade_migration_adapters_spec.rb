# frozen_string_literal: true

require 'spec_helper'
require 'active_record'
require 'active_support/core_ext/string/inflections'
require 'erb'
require 'ripper'
require 'securerandom'

class UpgradeMigrationTemplateContext
  attr_reader :adapter

  def initialize(adapter)
    @adapter = adapter
  end

  def migration_version = '[8.1]'
  def prepare_migration_class_name = 'PrepareRubyLlmV2Upgrade'
  def backfill_migration_class_name = 'BackfillRubyLlmV2Data'
  def finish_migration_class_name = 'FinishRubyLlmV2Upgrade'
  def reference_type = 'bigint'
  def chat_table_name = 'chats'
  def message_table_name = 'messages'
  def chat_model_name = 'Chat'
  def message_model_name = 'Message'
  def v1_model_table_name = 'models'
  def v1_tool_call_table_name = 'tool_calls'
  def v1_model_foreign_key = 'model_id'
  def v1_tool_call_foreign_key = 'tool_call_id'
  def message_foreign_key = 'message_id'
  def chat_foreign_key = 'chat_id'
  def postgresql? = adapter == 'postgresql'
  def mysql? = adapter == 'mysql2'
  def usage_operations_sql = sql_list(%w[chat embedding moderation image speech transcription ocr rerank])
  def usage_statuses_sql = sql_list(%w[pending succeeded failed cancelled])

  def create_migration_class_name(table_name)
    "Create#{table_name.camelize}"
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
  it 'renders valid migrations for every supported adapter' do
    templates = %w[prepare_v2_upgrade.rb.tt backfill_v2_data.rb.tt finish_v2_upgrade.rb.tt]

    %w[postgresql mysql2 sqlite3].each do |adapter|
      templates.each do |filename|
        template = File.expand_path("../../../lib/generators/ruby_llm/upgrade/templates/#{filename}", __dir__)
        source = UpgradeMigrationTemplateContext.new(adapter).render(template)

        expect(Ripper.sexp(source)).not_to be_nil, "#{filename} produced invalid Ruby for #{adapter}"
      end
    end
  end

  databases = {
    postgresql: ['postgresql', ENV.fetch('RUBY_LLM_POSTGRES_URL', nil)],
    mysql: ['mysql2', ENV.fetch('RUBY_LLM_MYSQL_URL', nil)],
    sqlite: ['sqlite3', { adapter: 'sqlite3', database: ':memory:' }]
  }

  databases.each do |name, (adapter, url)|
    next unless url

    context "with #{name}" do
      it 'moves a populated 1.16 schema to the clean 2.0 contract' do
        success, output = run_in_isolated_process(adapter, url)

        expect(success).to be(true), output
      end
    end
  end

  def run_in_isolated_process(adapter, database)
    reader, writer = IO.pipe
    pid = fork do
      reader.close
      success = true
      output = nil
      begin
        isolate_database(adapter, database) { run_adapter_scenario(adapter) }
      rescue Exception => e # rubocop:disable Lint/RescueException
        success = false
        output = e.full_message
      ensure
        writer.write(Marshal.dump([success, output]))
        writer.close
      end
      exit! success ? 0 : 1
    end
    writer.close
    result = Marshal.load(reader.read) # rubocop:disable Security/MarshalLoad
    reader.close
    Process.wait(pid)
    result
  end

  def isolate_database(adapter, database, &block)
    ActiveRecord::Base.establish_connection(database)
    ActiveRecord::Migration.verbose = false
    return block.call unless %w[postgresql mysql2].include?(adapter)

    adapter == 'postgresql' ? isolate_postgresql(&block) : isolate_mysql(&block)
  ensure
    ActiveRecord::Base.remove_connection
  end

  def isolate_postgresql
    original_path = connection.schema_search_path
    schema = "ruby_llm_upgrade_#{Process.pid}_#{SecureRandom.hex(4)}"
    connection.execute("CREATE SCHEMA #{connection.quote_table_name(schema)}")
    connection.schema_search_path = schema
    yield
  ensure
    if schema
      connection.schema_search_path = original_path
      connection.execute("DROP SCHEMA IF EXISTS #{connection.quote_table_name(schema)} CASCADE")
    end
  end

  def isolate_mysql
    original_config = ActiveRecord::Base.connection_db_config.configuration_hash
    database = "ruby_llm_upgrade_#{Process.pid}_#{SecureRandom.hex(4)}"
    connection.create_database(database, charset: 'utf8mb4')
    ActiveRecord::Base.establish_connection(original_config.merge(database: database))
    yield
  ensure
    if database
      ActiveRecord::Base.establish_connection(original_config)
      connection.drop_database(database)
    end
  end

  def run_adapter_scenario(adapter)
    create_v1_schema(adapter)
    insert_v1_records
    migrations = load_upgrade_migrations(adapter)

    migrations.fetch(:prepare).new.migrate(:up)
    migrations.fetch(:backfill).new.migrate(:up)
    record_for(:ruby_llm_usages).where('message_id > ?', 10_000).delete_all
    record_for(:ruby_llm_v2_backfills).where(task: 'usages').update_all(last_id: 10_000, completed: false)
    migrations.fetch(:backfill).new.migrate(:up)
    migrations.fetch(:finish).new.migrate(:up)

    verify_migrated_data
    verify_clean_install_contract(adapter)
    verify_preflight_guard(adapter, migrations)
    verify_finish_guard(adapter, migrations)
  ensure
    drop_test_tables
  end

  def verify_migrated_data
    verify_usage_data
    verify_tool_call_data
    verify_message_data
    verify_legacy_columns_removed
  end

  def verify_usage_data
    unless connection.select_value('SELECT COUNT(*) FROM ruby_llm_usages').to_i == synthetic_message_count
      raise 'usage count mismatch'
    end

    raise 'model count mismatch' unless connection.select_value('SELECT COUNT(*) FROM ruby_llm_models').to_i == 1

    costs = record_for(:ruby_llm_usages).where(message_id: [1, 2]).order(:message_id).pluck(:total_cost)
    raise 'direct total cost was not preserved' unless costs.first.to_d == 1.25.to_d
    raise 'detailed total cost was not preserved' unless costs.last.to_d == 2.5.to_d
  end

  def verify_tool_call_data
    tool_call = connection.select_one('SELECT * FROM ruby_llm_tool_calls')
    raise 'tool-call message was not preserved' unless tool_call['message_type'] == 'Message'
    raise 'tool-call result was not preserved' unless tool_call['result_type'] == 'Message'
  end

  def verify_message_data
    message_record = record_for(:messages)
    message_record.reset_column_information
    message = message_record.find(1)
    raise 'structured content text was not preserved' unless JSON.parse(message.content) == { 'answer' => 42 }
    raise 'structured raw content was not preserved' unless message.raw_content == { 'answer' => 42 }
  end

  def verify_legacy_columns_removed
    removed = %w[
      content_raw model_id tool_call_id input_tokens output_tokens cached_tokens
      cache_creation_tokens thinking_tokens
    ]
    raise 'legacy message columns remain' if connection.columns(:messages).map(&:name).intersect?(removed)
  end

  def verify_clean_install_contract(adapter)
    upgraded_contract = internal_schema_contract
    drop_test_tables
    create_clean_internal_schema(adapter)
    raise 'upgraded schema differs from a clean install' unless internal_schema_contract == upgraded_contract
  end

  def verify_preflight_guard(adapter, migrations)
    drop_test_tables
    create_v1_schema(adapter)
    insert_identity_records
    now = Time.now.utc
    record_for(:messages).create!(id: 1, chat_id: 1, model_id: 1, role: 'assistant', created_at: now, updated_at: now)
    record_for(:tool_calls).create!(
      id: 1, message_id: 1, tool_call_id: 'duplicate-result', name: 'calculator', arguments: {},
      created_at: now, updated_at: now
    )
    [2, 3].each do |id|
      record_for(:messages).create!(
        id: id, chat_id: 1, model_id: 1, tool_call_id: 1, role: 'tool', content: id.to_s,
        created_at: now, updated_at: now
      )
    end

    error = migration_error { migrations.fetch(:prepare).new.migrate(:up) }
    raise 'ambiguous tool results passed preflight' unless error&.message&.include?('Multiple messages reference')
    raise 'preflight changed tables before failing' unless connection.table_exists?(:models)
    raise 'preflight changed chats before failing' if connection.column_exists?(:chats, :cancelled)
  end

  def verify_finish_guard(adapter, migrations)
    drop_test_tables
    create_v1_schema(adapter)
    insert_identity_records
    now = Time.now.utc
    record_for(:messages).create!(
      id: 1, chat_id: 1, model_id: 1, role: 'assistant', input_tokens: 12,
      created_at: now, updated_at: now
    )
    migrations.fetch(:prepare).new.migrate(:up)
    migrations.fetch(:backfill).new.migrate(:up)
    record_for(:ruby_llm_usages).delete_all

    error = migration_error { migrations.fetch(:finish).new.migrate(:up) }
    raise 'finish accepted missing usage data' unless error&.message&.include?('did not receive')
    return if connection.column_exists?(:messages, :input_tokens)

    raise 'finish removed source columns after failed reconciliation'
  end

  def migration_error
    yield
    nil
  rescue StandardError => e
    e
  end

  def connection
    ActiveRecord::Base.connection
  end

  def drop_test_tables
    connection.disable_referential_integrity do
      %i[
        ruby_llm_usages messages chats ruby_llm_tool_calls tool_calls ruby_llm_batches
        ruby_llm_models models ruby_llm_v2_backfills
      ].each do |table|
        connection.drop_table(table, force: :cascade) if connection.table_exists?(table)
      end
    end
  end

  def create_v1_schema(adapter)
    registry_json_type = adapter == 'postgresql' ? :jsonb : :json
    json_defaults = adapter == 'mysql2' ? {} : { default: {} }

    ActiveRecord::Schema.define do
      create_table :models do |table|
        table.string :model_id, null: false
        table.string :name, null: false
        table.string :provider, null: false
        table.string :family
        table.datetime :model_created_at
        table.integer :context_window
        table.integer :max_output_tokens
        table.date :knowledge_cutoff
        table.public_send(registry_json_type, :modalities, **json_defaults)
        table.public_send(registry_json_type, :capabilities, **(adapter == 'mysql2' ? {} : { default: [] }))
        table.public_send(registry_json_type, :pricing, **json_defaults)
        table.public_send(registry_json_type, :metadata, **json_defaults)
        table.timestamps
        table.index %i[provider model_id], unique: true
        table.index :provider
        table.index :family
        if adapter == 'postgresql'
          table.index :capabilities, using: :gin
          table.index :modalities, using: :gin
        end
      end

      create_table(:chats, &:timestamps)

      create_table :messages do |table|
        table.string :role, null: false
        table.text :content
        table.json :content_raw
        table.text :thinking_text
        table.text :thinking_signature
        table.integer :thinking_tokens
        table.integer :input_tokens
        table.integer :output_tokens
        table.integer :cached_tokens
        table.integer :cache_creation_tokens
        table.decimal :total_cost, precision: 16, scale: 10
        table.public_send(registry_json_type, :cost_details)
        table.timestamps
        table.index :role
      end

      create_table :tool_calls do |table|
        table.string :tool_call_id, null: false
        table.string :name, null: false
        table.text :thought_signature
        table.public_send(registry_json_type, :arguments, **json_defaults)
        table.timestamps
        table.index :tool_call_id, unique: true
        table.index :name
      end

      add_reference :chats, :model, foreign_key: true
      add_reference :tool_calls, :message, null: false, foreign_key: true
      add_reference :messages, :chat, null: false, foreign_key: true
      add_reference :messages, :model, foreign_key: true
      add_reference :messages, :tool_call, foreign_key: true
    end
  end

  def insert_v1_records
    now = Time.now.utc
    record_for(:models).create!(
      id: 1,
      model_id: 'gpt-adapter-test',
      name: 'Adapter Test',
      provider: 'openai',
      modalities: {},
      capabilities: [],
      pricing: {},
      metadata: {},
      created_at: now,
      updated_at: now
    )
    record_for(:chats).create!(id: 1, model_id: 1, created_at: now, updated_at: now)

    rows = (1..synthetic_message_count).map do |id|
      {
        id:,
        chat_id: 1,
        model_id: id.odd? ? 1 : nil,
        role: 'assistant',
        content: id == 1 ? nil : "answer #{id}",
        content_raw: id == 1 ? { answer: 42 } : nil,
        input_tokens: id,
        output_tokens: 1,
        cached_tokens: 2,
        cache_creation_tokens: 3,
        thinking_tokens: 4,
        total_cost: id == 1 ? 1.25 : nil,
        cost_details: id == 2 ? { total: 2.5, input: 1.0, output: 1.5 } : nil,
        created_at: now,
        updated_at: now
      }
    end
    rows.each_slice(1_000) { |slice| record_for(:messages).insert_all!(slice, returning: false) }
    record_for(:tool_calls).create!(
      id: 1,
      message_id: 1,
      tool_call_id: 'call-adapter-test',
      name: 'calculator',
      arguments: { expression: '6 * 7' },
      created_at: now,
      updated_at: now
    )
    record_for(:messages).create!(
      id: synthetic_message_count + 1,
      chat_id: 1,
      model_id: 1,
      tool_call_id: 1,
      role: 'tool',
      content: '42',
      created_at: now,
      updated_at: now
    )
  end

  def insert_identity_records
    now = Time.now.utc
    record_for(:models).create!(
      id: 1, model_id: 'gpt-adapter-test', name: 'Adapter Test', provider: 'openai',
      modalities: {}, capabilities: [], pricing: {}, metadata: {}, created_at: now, updated_at: now
    )
    record_for(:chats).create!(id: 1, model_id: 1, created_at: now, updated_at: now)
  end

  def synthetic_message_count = 20_005

  def record_for(table)
    Class.new(ActiveRecord::Base) do
      self.table_name = table.to_s
      self.inheritance_column = :_type_disabled
    end
  end

  def load_upgrade_migrations(adapter)
    context = UpgradeMigrationTemplateContext.new(adapter)
    scope = Module.new
    {
      prepare: ['prepare_v2_upgrade.rb.tt', :PrepareRubyLlmV2Upgrade],
      backfill: ['backfill_v2_data.rb.tt', :BackfillRubyLlmV2Data],
      finish: ['finish_v2_upgrade.rb.tt', :FinishRubyLlmV2Upgrade]
    }.transform_values do |filename, class_name|
      template = File.expand_path("../../../lib/generators/ruby_llm/upgrade/templates/#{filename}", __dir__)
      scope.module_eval(context.render(template), template)
      scope.const_get(class_name)
    end
  end

  def create_clean_internal_schema(adapter)
    context = UpgradeMigrationTemplateContext.new(adapter)
    template = File.expand_path(
      '../../../lib/generators/ruby_llm/install/templates/create_ruby_llm_records_migration.rb.tt',
      __dir__
    )
    scope = Module.new
    scope.module_eval(context.render(template), template)
    scope.const_get(:CreateRubyLlmRecords).new.migrate(:up)
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
      [table, { primary_key: connection.primary_key(table), columns:, indexes:, constraints: }]
    end
  end

  def schema_sql_type(column)
    return column.type.to_s if connection.adapter_name == 'SQLite'

    column.sql_type
  end
end
