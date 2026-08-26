# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/upgrade/upgrade_generator'
require_relative '../../support/generator_test_helpers'

RSpec.describe 'RubyLLM upgrade generator', :generator, type: :generator do # rubocop:disable RSpec/DescribeClass
  include GeneratorTestHelpers

  def migrations_containing(pattern)
    Dir.glob('db/migrate/*.rb').select { |path| path.include?(pattern) }
  end

  describe 'with default model names' do
    let(:app_name) { 'test_upgrade_generator_default' }
    let(:app_path) { File.join(Dir.tmpdir, app_name) }

    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      template_path = File.expand_path('../../fixtures/templates', __dir__)
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_upgrade_generator_default'))
      GeneratorTestHelpers.create_test_app(
        'test_upgrade_generator_default',
        template: 'upgrade_generators_default_template.rb',
        template_path: template_path
      )
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_upgrade_generator_default'))
    end

    it 'creates the v2.0 migration for RubyLLM-owned records' do
      within_test_app(app_path) do
        migration_path = migrations_containing('add_ruby_llm_v2_0_columns').first
        expect(migration_path).not_to be_nil

        migration = File.read(migration_path)
        expect(migration).to include('disable_ddl_transaction!')
        expect(migration).to include('add_column :chats, :cancelled, :boolean')
        expect(migration).to include('table.json :citations')
        expect(migration).to include('table.string :finish_reason')
        expect(migration).to include('table.boolean :cache_until_here')
        expect(migration).to include('create_table :ruby_llm_models')
        expect(migration).to include('create_table :ruby_llm_tool_calls')
        expect(migration).to include('create_table :ruby_llm_usages')
        expect(migration).to include('create_table :ruby_llm_batches')
        expect(migration).to include('def backfill_legacy_content_raw')
        expect(migration).to include('USAGE_PROGRESS_TABLE = :ruby_llm_v2_usage_backfill')
        expect(migration).to include('execute usage_insert_sql(candidate, provider, model)')
      end
    end

    it 'moves a legacy schema into RubyLLM-owned tables without losing data' do
      within_test_app(app_path) do
        setup = <<~RUBY
          migration_path = Dir.glob(Rails.root.join('db/migrate/*_add_ruby_llm_v2_0_columns.rb')).sole
          load migration_path
          unless defined?(StrongMigrations) && AddRubyLlmV20Columns.new.respond_to?(:safety_assured, true)
            abort 'Strong Migrations is not available to the generated migration'
          end

          connection = ActiveRecord::Base.connection
          ActiveRecord::Schema.define do
            create_table :models do |t|
              t.string :model_id, null: false
              t.string :name, null: false
              t.string :provider, null: false
              t.string :family
              t.datetime :model_created_at
              t.integer :context_window
              t.integer :max_output_tokens
              t.date :knowledge_cutoff
              t.json :modalities
              t.json :capabilities
              t.json :pricing
              t.json :metadata
              t.timestamps
            end
            add_index :models, [:provider, :model_id]
            create_table :chats do |t|
              t.bigint :model_id
              t.timestamps
            end
            create_table :tool_calls do |t|
              t.bigint :message_id, null: false
              t.string :tool_call_id, null: false
              t.string :name, null: false
              t.json :arguments
              t.timestamps
            end
            add_index :tool_calls, :message_id
            add_index :tool_calls, :tool_call_id
            create_table :messages do |t|
              t.bigint :chat_id, null: false
              t.bigint :model_id
              t.bigint :tool_call_id
              t.string :role, null: false
              t.text :content
              t.json :content_raw
              t.integer :input_tokens
              t.integer :output_tokens
              t.integer :cached_tokens
              t.integer :cache_creation_tokens
              t.decimal :total_cost, precision: 16, scale: 10
              t.json :cost_details
              t.timestamps
            end
            create_table :batches do |t|
              t.string :provider_batch_id, null: false
              t.string :provider, null: false
              t.string :status
              t.boolean :completed, null: false, default: false
              t.json :chat_ids
              t.timestamps
            end
            add_index :batches, [:provider, :provider_batch_id]
          end

          connection.execute <<~SQL
            INSERT INTO models
              (id, model_id, name, provider, modalities, capabilities, pricing, metadata, created_at, updated_at)
            VALUES
              (1, 'gpt-legacy', 'Legacy GPT', 'openai', '{}', '[]', '{}', '{}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
              (2, 'gpt-legacy', 'Duplicate GPT', 'openai', '{}', '[]', '{}', '{}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          SQL
          connection.execute <<~SQL
            INSERT INTO chats (id, model_id, created_at, updated_at)
            VALUES
              (1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
              (2, 999, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          SQL
          connection.execute <<~SQL
            INSERT INTO messages
              (id, chat_id, model_id, role, content, input_tokens, output_tokens, created_at, updated_at)
            VALUES
              (1, 1, 1, 'assistant', NULL, 7, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
              (2, 1, 1, 'tool', '9', NULL, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
              (3, 1, 1, 'assistant', 'cost only', NULL, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
              (4, 1, NULL, 'assistant', 'no usage reported', NULL, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          SQL
          connection.execute <<~SQL
            UPDATE messages
            SET total_cost = 0.0123, cost_details = '{"input":0.004,"output":0.0083,"total":0.0123}'
            WHERE id = 3
          SQL
          connection.execute <<~SQL
            UPDATE messages SET content_raw = '{"name":"Alice","age":25}' WHERE id = 1
          SQL
          connection.execute <<~SQL
            UPDATE messages SET content_raw = '[{"type":"text","text":"raw"}]' WHERE id = 3
          SQL
          message_record = Class.new(ActiveRecord::Base) { self.table_name = 'messages' }
          now = Time.current
          message_record.insert_all!((5..1_005).map do |id|
            {
              id: id,
              chat_id: 1,
              model_id: 1,
              role: 'assistant',
              content: "bulk " + id.to_s,
              input_tokens: id,
              output_tokens: 1,
              created_at: now,
              updated_at: now
            }
          end)
          message_record.create!(
            id: 1_006,
            chat_id: 2,
            role: 'assistant',
            content: 'missing model',
            input_tokens: 3,
            output_tokens: 1
          )
          message_record.create!(
            id: 1_007,
            chat_id: 1,
            role: 'user',
            content: 'empty cost details',
            cost_details: {}
          )
          connection.execute <<~SQL
            INSERT INTO tool_calls
              (id, message_id, tool_call_id, name, arguments, created_at, updated_at)
            VALUES
              (1, 1, 'call_legacy', 'calculator', '{"expression":"4 + 5"}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
              (2, 1, 'call_legacy', 'calculator', '{"expression":"5 + 6"}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          SQL
          connection.execute('UPDATE messages SET tool_call_id = 1 WHERE id = 2')
          connection.execute <<~SQL
            INSERT INTO batches
              (provider_batch_id, provider, status, completed, chat_ids, created_at, updated_at)
            VALUES
              ('batch_legacy', 'openai', 'completed', 1, '[1]', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          SQL
        RUBY
        success, output = run_rails_runner(setup)
        expect(success).to be(true), output

        env = {
          'BUNDLE_GEMFILE' => ENV.fetch('BUNDLE_GEMFILE'),
          'BUNDLE_IGNORE_CONFIG' => '1',
          'OPENAI_API_KEY' => ENV.fetch('OPENAI_API_KEY', 'test')
        }
        output, status = GeneratorTestHelpers.run_command(env, %w[bundle exec rails db:migrate], chdir: Dir.pwd)
        expect(status.success?).to be(false)
        expect(output).to include('Cannot add a unique index to models on provider, model_id')

        preflight = <<~RUBY
          connection = ActiveRecord::Base.connection
          unchanged = connection.table_exists?(:models) &&
                      !connection.table_exists?(:ruby_llm_models) &&
                      !connection.column_exists?(:chats, :cancelled)
          connection.execute('DELETE FROM models WHERE id = 2')
          exit(unchanged ? 0 : 1)
        RUBY
        success, output = run_rails_runner(preflight)
        expect(success).to be(true), output

        output, status = GeneratorTestHelpers.run_command(env, %w[bundle exec rails db:migrate], chdir: Dir.pwd)
        expect(status.success?).to be(false)
        expect(output).to include('Could not find models record for chats id 2')

        repair_orphan = "ActiveRecord::Base.connection.execute('UPDATE chats SET model_id = NULL WHERE id = 2')"
        success, output = run_rails_runner(repair_orphan)
        expect(success).to be(true), output

        output, status = GeneratorTestHelpers.run_command(env, %w[bundle exec rails db:migrate], chdir: Dir.pwd)
        expect(status.success?).to be(false)
        expect(output).to include('Could not determine provider and model for messages id 1006')

        partial = <<~RUBY
          connection = ActiveRecord::Base.connection
          unchanged = connection.table_exists?(:models) &&
                      !connection.table_exists?(:ruby_llm_models) &&
                      !connection.table_exists?(:ruby_llm_usages) &&
                      !connection.table_exists?(:ruby_llm_v2_usage_backfill) &&
                      !connection.column_exists?(:chats, :cancelled)
          exit(unchanged ? 0 : 1)
        RUBY
        success, output = run_rails_runner(partial)
        expect(success).to be(true), output

        repair = "ActiveRecord::Base.connection.execute('UPDATE chats SET model_id = 1 WHERE id = 2')"
        success, output = run_rails_runner(repair)
        expect(success).to be(true), output

        interrupt = <<~RUBY
          migration_path = Dir.glob(Rails.root.join('db/migrate/*_add_ruby_llm_v2_0_columns.rb')).sole
          load migration_path
          interrupted_migration = Class.new(AddRubyLlmV20Columns) do
            def normalize_usage_indexes
              raise 'simulated interruption after usage commit'
            end
          end
          begin
            interrupted_migration.new.migrate(:up)
            exit(1)
          rescue StandardError => error
            exit(error.message == 'simulated interruption after usage commit' ? 0 : 1)
          end
        RUBY
        success, output = run_rails_runner(interrupt)
        expect(success).to be(true), output

        interrupted = <<~RUBY
          connection = ActiveRecord::Base.connection
          usages = connection.select_value('SELECT COUNT(*) FROM ruby_llm_usages').to_i
          progress = connection.select_value('SELECT COUNT(*) FROM ruby_llm_v2_usage_backfill').to_i
          legacy_columns_remain = connection.column_exists?(:messages, :input_tokens) &&
                                  connection.column_exists?(:messages, :model_id)
          exit(usages == 1_005 && progress == 1 && legacy_columns_remain ? 0 : 1)
        RUBY
        success, output = run_rails_runner(interrupted)
        expect(success).to be(true), output

        output, status = GeneratorTestHelpers.run_command(env, %w[bundle exec rails db:migrate], chdir: Dir.pwd)
        expect(status.success?).to be(true), output

        verify = <<~RUBY
          connection = ActiveRecord::Base.connection
          model = connection.select_one('SELECT * FROM ruby_llm_models')
          chat = connection.select_one('SELECT * FROM chats WHERE id = 1')
          tool_call = connection.select_one('SELECT * FROM ruby_llm_tool_calls WHERE id = 1')
          duplicate_tool_call = connection.select_one('SELECT * FROM ruby_llm_tool_calls WHERE id = 2')
          batch = connection.select_one('SELECT * FROM ruby_llm_batches')
          structured_message = connection.select_one('SELECT * FROM messages WHERE id = 1')
          existing_content_message = connection.select_one('SELECT * FROM messages WHERE id = 3')

          ok = model['model_id'] == 'gpt-legacy' &&
               chat['ruby_llm_model_id'].to_i == model['id'].to_i && !chat.key?('provider') &&
               tool_call['message_type'] == 'Message' && tool_call['message_id'].to_i == 1 &&
               tool_call['result_type'] == 'Message' && tool_call['result_id'].to_i == 2 &&
               duplicate_tool_call['tool_call_id'] == 'call_legacy-migrated-2' &&
               batch['provider_batch_id'] == 'batch_legacy' && batch['chat_type'] == 'Chat' &&
               JSON.parse(structured_message['content']) == {'name' => 'Alice', 'age' => 25} &&
               structured_message['content_raw'] && existing_content_message['content'] == 'cost only' &&
               !connection.table_exists?(:models) && !connection.table_exists?(:tool_calls) &&
               !connection.table_exists?(:batches)
          model_foreign_key = connection.foreign_keys(:chats).find { |key| key.column == 'ruby_llm_model_id' }
          ok &&= model_foreign_key&.to_table == 'ruby_llm_models'
          tool_call_index = connection.indexes(:ruby_llm_tool_calls).find do |index|
            index.columns == ['tool_call_id']
          end
          ok &&= tool_call_index&.unique
          old_message_index = connection.indexes(:ruby_llm_tool_calls).find do |index|
            index.columns == ['message_id']
          end
          ok &&= old_message_index.nil?
          model_index = connection.indexes(:ruby_llm_models).find do |index|
            index.columns == ['provider', 'model_id']
          end
          batch_index = connection.indexes(:ruby_llm_batches).find do |index|
            index.columns == ['provider', 'provider_batch_id']
          end
          ok &&= model_index&.unique && batch_index&.unique
          ok &&= connection.index_exists?(:ruby_llm_models, :provider)
          ok &&= connection.index_exists?(:ruby_llm_models, :family)
          ok &&= connection.columns(:ruby_llm_tool_calls).map(&:name).include?('thought_signature')
          ok &&= connection.columns(:ruby_llm_models).map(&:name).include?('unlisted_at')

          entry = connection.select_one('SELECT * FROM ruby_llm_usages WHERE message_id = 1')
          cost_only_entry = connection.select_one('SELECT * FROM ruby_llm_usages WHERE message_id = 3')
          no_tokens_entry = connection.select_one('SELECT * FROM ruby_llm_usages WHERE message_id = 4')
          fallback_entry = connection.select_one('SELECT * FROM ruby_llm_usages WHERE message_id = 1006')
          message_columns = connection.columns(:messages).map(&:name)
          legacy_columns = %w[input_tokens output_tokens cache_read_tokens cache_write_tokens
                              thinking_tokens total_cost cost_details model_id ruby_llm_v2_model_id
                              ruby_llm_v2_provider]
          ok &&= connection.select_value('SELECT COUNT(*) FROM ruby_llm_usages').to_i == 1_005 &&
                 entry['chat_type'] == 'Chat' && entry['chat_id'].to_i == 1 &&
                 entry['message_type'] == 'Message' && entry['message_id'].to_i == 1 &&
                 entry['operation'] == 'chat' && entry['status'] == 'succeeded' &&
                 entry['provider'] == 'openai' && entry['model'] == 'gpt-legacy' &&
                 entry['input_tokens'].to_i == 7 && entry['output_tokens'].to_i == 2 &&
                 cost_only_entry['input_tokens'].nil? && cost_only_entry['output_tokens'].nil? &&
                 cost_only_entry['input_cost'].to_f == 0.004 &&
                 cost_only_entry['output_cost'].to_f == 0.0083 &&
                 cost_only_entry['total_cost'].to_f == 0.0123 &&
                 no_tokens_entry['provider'] == 'openai' && no_tokens_entry['model'] == 'gpt-legacy' &&
                 no_tokens_entry['input_tokens'].nil? && no_tokens_entry['output_tokens'].nil? &&
                 fallback_entry['provider'] == 'openai' && fallback_entry['model'] == 'gpt-legacy' &&
                 fallback_entry['input_tokens'].to_i == 3 && fallback_entry['output_tokens'].to_i == 1 &&
                 (message_columns & legacy_columns).empty? &&
                 !connection.table_exists?(:ruby_llm_v2_usage_backfill)
          exit(ok ? 0 : 1)
        RUBY
        success, output = run_rails_runner(verify)
        expect(success).to be(true), output
      end
    end
  end

  describe 'with custom model mappings' do
    let(:app_name) { 'test_upgrade_generator_custom_mappings' }
    let(:app_path) { File.join(Dir.tmpdir, app_name) }

    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      template_path = File.expand_path('../../fixtures/templates', __dir__)
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_upgrade_generator_custom_mappings'))
      GeneratorTestHelpers.create_test_app(
        'test_upgrade_generator_custom_mappings',
        template: 'upgrade_generators_custom_mappings_template.rb',
        template_path: template_path
      )
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_upgrade_generator_custom_mappings'))
    end

    it 'creates a v2.0 migration targeting fully namespaced legacy tables' do
      within_test_app(app_path) do
        migration_path = migrations_containing('add_ruby_llm_v2_0_columns').first
        expect(migration_path).not_to be_nil

        migration = File.read(migration_path)
        expect(migration).to include('add_column :ai_chats, :cancelled, :boolean')
        expect(migration).to include('change_table :ai_chat_messages, bulk: true')
        expect(migration).to include('table.json :citations')
        expect(migration).to include('table.string :finish_reason')
        expect(migration).to include('table.boolean :cache_until_here')
        expect(migration).to include('create_table :ruby_llm_batches')
        expect(migration).to include('move_table(:ai_llm_models, :ruby_llm_models)')
        expect(migration).to include('move_table(:ai_chat_tool_calls, :ruby_llm_tool_calls)')
        expect(migration).to include('legacy_message_column = :ai_chat_message_id')
        expect(migration).to include('result_column = :ai_chat_tool_call_id')
      end
    end

    it 'moves namespaced supporting tables while preserving external references' do
      within_test_app(app_path) do
        setup = <<~RUBY
          connection = ActiveRecord::Base.connection
          ActiveRecord::Schema.define do
            create_table :ai_llm_models do |t|
              t.string :model_id, null: false
              t.string :name, null: false
              t.string :provider, null: false
              t.string :family
              t.json :modalities
              t.json :capabilities
              t.json :pricing
              t.json :metadata
              t.timestamps
              t.index [:provider, :model_id], unique: true
            end
            create_table :ai_chats do |t|
              t.bigint :ai_llm_model_id
              t.timestamps
            end
            add_foreign_key :ai_chats, :ai_llm_models
            create_table :ai_chat_messages do |t|
              t.bigint :ai_chat_id, null: false
              t.bigint :ai_chat_tool_call_id
              t.bigint :ai_llm_model_id
              t.string :role, null: false
              t.text :content
              t.integer :input_tokens
              t.integer :output_tokens
              t.decimal :cost_dollars, precision: 12, scale: 8
              t.timestamps
            end
            add_foreign_key :ai_chat_messages, :ai_chats
            add_foreign_key :ai_chat_messages, :ai_llm_models
            create_table :ai_chat_tool_calls do |t|
              t.bigint :ai_chat_message_id, null: false
              t.string :tool_call_id, null: false
              t.string :name, null: false
              t.json :arguments
              t.timestamps
              t.index :tool_call_id, unique: true
            end
            add_foreign_key :ai_chat_tool_calls, :ai_chat_messages
            add_foreign_key :ai_chat_messages, :ai_chat_tool_calls
            create_table :ai_chat_actions do |t|
              t.bigint :ai_chat_tool_call_id, null: false
              t.timestamps
            end
            add_foreign_key :ai_chat_actions, :ai_chat_tool_calls
            create_table :ai_logs do |t|
              t.bigint :ai_llm_model_id
              t.timestamps
            end
            add_foreign_key :ai_logs, :ai_llm_models
            create_table :batches do |t|
              t.string :name, null: false
              t.string :provider
              t.string :provider_batch_id
              t.json :chat_ids
              t.timestamps
            end
          end

          ActiveRecord::Base.connection.execute(<<~SQL)
            INSERT INTO ai_llm_models
              (id, model_id, name, provider, modalities, capabilities, pricing, metadata, created_at, updated_at)
            VALUES (1, 'gpt-namespaced', 'Namespaced GPT', 'openai', '{}', '[]', '{}', '{}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          SQL
          connection.execute("INSERT INTO ai_chats VALUES (1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
          connection.execute <<~SQL
            INSERT INTO ai_chat_messages
              (id, ai_chat_id, ai_llm_model_id, role, content, input_tokens, output_tokens, cost_dollars, created_at, updated_at)
            VALUES
              (1, 1, 1, 'assistant', '', 12, 4, 0.25, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
              (2, 1, 1, 'tool', 'done', NULL, NULL, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          SQL
          connection.execute <<~SQL
            INSERT INTO ai_chat_tool_calls
              (id, ai_chat_message_id, tool_call_id, name, arguments, created_at, updated_at)
            VALUES (1, 1, 'call_namespaced', 'search', '{}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          SQL
          connection.execute("UPDATE ai_chat_messages SET ai_chat_tool_call_id = 1 WHERE id = 2")
          connection.execute("INSERT INTO ai_chat_actions VALUES (1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
          connection.execute("INSERT INTO ai_logs VALUES (1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
          connection.execute("INSERT INTO batches (name, created_at, updated_at) VALUES ('imports', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        RUBY
        success, output = run_rails_runner(setup)
        expect(success).to be(true), output

        env = {
          'BUNDLE_GEMFILE' => ENV.fetch('BUNDLE_GEMFILE'),
          'BUNDLE_IGNORE_CONFIG' => '1',
          'OPENAI_API_KEY' => ENV.fetch('OPENAI_API_KEY', 'test')
        }
        output, status = GeneratorTestHelpers.run_command(env, %w[bundle exec rails db:migrate], chdir: Dir.pwd)
        expect(status.success?).to be(true), output

        verify = <<~RUBY
          connection = ActiveRecord::Base.connection
          message = connection.select_one('SELECT * FROM ai_chat_messages WHERE id = 1')
          result = connection.select_one('SELECT * FROM ai_chat_messages WHERE id = 2')
          tool_call = connection.select_one('SELECT * FROM ruby_llm_tool_calls WHERE id = 1')
          usage = connection.select_one('SELECT * FROM ruby_llm_usages WHERE message_id = 1')
          action_fk = connection.foreign_keys(:ai_chat_actions).find { |key| key.column == 'ai_chat_tool_call_id' }
          log_fk = connection.foreign_keys(:ai_logs).find { |key| key.column == 'ai_llm_model_id' }

          ok = !connection.table_exists?(:ai_llm_models) &&
               !connection.table_exists?(:ai_chat_tool_calls) &&
               connection.table_exists?(:ruby_llm_models) &&
               connection.table_exists?(:ruby_llm_tool_calls) &&
               connection.table_exists?(:batches) && connection.table_exists?(:ruby_llm_batches) &&
               connection.select_value('SELECT name FROM batches') == 'imports' &&
               connection.index_exists?(:ruby_llm_batches, [:provider, :provider_batch_id], unique: true) &&
               connection.index_exists?(:ruby_llm_batches, :status) &&
               !message.key?('ai_llm_model_id') && !message.key?('ruby_llm_v2_model_id') &&
               !message.key?('ruby_llm_v2_provider') &&
               message['cost_dollars'].to_f == 0.25 &&
               !message.key?('input_tokens') && !message.key?('output_tokens') &&
               !result.key?('ai_chat_tool_call_id') &&
               tool_call['message_type'] == 'AI::Chat::Message' &&
               tool_call['result_type'] == 'AI::Chat::Message' && tool_call['result_id'].to_i == 2 &&
               usage['chat_type'] == 'AI::Chat' && usage['message_type'] == 'AI::Chat::Message' &&
               usage['provider'] == 'openai' && usage['model'] == 'gpt-namespaced' &&
               usage['input_tokens'].to_i == 12 && usage['output_tokens'].to_i == 4 &&
               action_fk&.to_table == 'ruby_llm_tool_calls' &&
               log_fk&.to_table == 'ruby_llm_models'
          exit(ok ? 0 : 1)
        RUBY
        success, output = run_rails_runner(verify)
        expect(success).to be(true), output
      end
    end
  end
end
