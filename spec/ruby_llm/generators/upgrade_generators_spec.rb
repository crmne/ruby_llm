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
        expect(migration).to include('add_column :chats, :cancelled, :boolean')
        expect(migration).to include('add_column :messages, :citations, :json')
        expect(migration).to include('add_column :messages, :finish_reason, :string')
        expect(migration).to include('add_column :messages, :cache_until_here, :boolean')
        expect(migration).to include('create_table :ruby_llm_models')
        expect(migration).to include('create_table :ruby_llm_tool_calls')
        expect(migration).to include('create_table :ruby_llm_usages')
        expect(migration).to include('create_table :ruby_llm_batches')
      end
    end

    it 'moves a legacy schema into RubyLLM-owned tables without losing data' do
      within_test_app(app_path) do
        setup = <<~RUBY
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
            create_table :messages do |t|
              t.bigint :chat_id, null: false
              t.bigint :model_id
              t.bigint :tool_call_id
              t.string :role, null: false
              t.text :content
              t.integer :input_tokens
              t.integer :output_tokens
              t.integer :cached_tokens
              t.integer :cache_creation_tokens
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
          end

          connection.execute <<~SQL
            INSERT INTO models
              (id, model_id, name, provider, modalities, capabilities, pricing, metadata, created_at, updated_at)
            VALUES
              (1, 'gpt-legacy', 'Legacy GPT', 'openai', '{}', '[]', '{}', '{}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          SQL
          connection.execute <<~SQL
            INSERT INTO chats (id, model_id, created_at, updated_at)
            VALUES (1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          SQL
          connection.execute <<~SQL
            INSERT INTO messages
              (id, chat_id, model_id, role, content, input_tokens, output_tokens, created_at, updated_at)
            VALUES
              (1, 1, 1, 'assistant', '', 7, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
              (2, 1, 1, 'tool', '9', NULL, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          SQL
          connection.execute <<~SQL
            INSERT INTO tool_calls
              (id, message_id, tool_call_id, name, arguments, created_at, updated_at)
            VALUES
              (1, 1, 'call_legacy', 'calculator', '{"expression":"4 + 5"}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
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
        expect(status.success?).to be(true), output

        verify = <<~RUBY
          connection = ActiveRecord::Base.connection
          model = connection.select_one('SELECT * FROM ruby_llm_models')
          chat = connection.select_one('SELECT * FROM chats WHERE id = 1')
          tool_call = connection.select_one('SELECT * FROM ruby_llm_tool_calls')
          batch = connection.select_one('SELECT * FROM ruby_llm_batches')

          ok = model['model_id'] == 'gpt-legacy' &&
               chat['ruby_llm_model_id'].to_i == model['id'].to_i && !chat.key?('provider') &&
               tool_call['message_type'] == 'Message' && tool_call['message_id'].to_i == 1 &&
               tool_call['result_type'] == 'Message' && tool_call['result_id'].to_i == 2 &&
               batch['provider_batch_id'] == 'batch_legacy' && batch['chat_type'] == 'Chat' &&
               !connection.table_exists?(:models) && !connection.table_exists?(:tool_calls) &&
               !connection.table_exists?(:batches)
          model_foreign_key = connection.foreign_keys(:chats).find { |key| key.column == 'ruby_llm_model_id' }
          ok &&= model_foreign_key&.to_table == 'ruby_llm_models'
          ok &&= connection.columns(:ruby_llm_tool_calls).map(&:name).include?('thought_signature')
          ok &&= connection.columns(:ruby_llm_models).map(&:name).include?('unlisted_at')

          entry = connection.select_one('SELECT * FROM ruby_llm_usages')
          message_columns = connection.columns(:messages).map(&:name)
          legacy_columns = %w[input_tokens output_tokens cache_read_tokens cache_write_tokens
                              thinking_tokens total_cost cost_details]
          ok &&= connection.select_value('SELECT COUNT(*) FROM ruby_llm_usages').to_i == 1 &&
                 entry['chat_type'] == 'Chat' && entry['chat_id'].to_i == 1 &&
                 entry['message_type'] == 'Message' && entry['message_id'].to_i == 1 &&
                 entry['operation'] == 'chat' && entry['status'] == 'succeeded' &&
                 entry['provider'] == 'openai' && entry['model'] == 'gpt-legacy' &&
                 entry['input_tokens'].to_i == 7 && entry['output_tokens'].to_i == 2 &&
                 (message_columns & legacy_columns).empty? &&
                 message_columns.include?('model_id') && message_columns.include?('provider')
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

    it 'creates a v2.0 migration targeting the mapped message table' do
      within_test_app(app_path) do
        migration_path = migrations_containing('add_ruby_llm_v2_0_columns').first
        expect(migration_path).not_to be_nil

        migration = File.read(migration_path)
        expect(migration).to include('add_column :chats, :cancelled, :boolean')
        expect(migration).to include('add_column :chat_messages, :citations, :json')
        expect(migration).to include('add_column :chat_messages, :finish_reason, :string')
        expect(migration).to include('add_column :chat_messages, :cache_until_here, :boolean')
        expect(migration).to include('create_table :ruby_llm_batches')
        expect(migration).to include('move_table(:tool_calls, :ruby_llm_tool_calls)')
        expect(migration).to include('legacy_message_column = :chat_message_id')
      end
    end
  end
end
