# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/upgrade_to_v1_7/upgrade_to_v1_7_generator'
require 'generators/ruby_llm/upgrade_to_v1_9/upgrade_to_v1_9_generator'
require_relative '../../support/generator_test_helpers'

RSpec.describe 'RubyLLM upgrade generators', :generator, type: :generator do # rubocop:disable RSpec/DescribeClass
  include GeneratorTestHelpers

  let(:template_path) { File.expand_path('../../fixtures/templates', __dir__) }

  def migrations_containing(pattern)
    Dir.glob('db/migrate/*.rb').select { |path| path.include?(pattern) }
  end

  describe 'with default model names' do
    let(:app_name) { 'test_upgrade_generators_default' }
    let(:app_path) { File.join(Dir.tmpdir, app_name) }

    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      template_path = File.expand_path('../../fixtures/templates', __dir__)
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_upgrade_generators_default'))
      GeneratorTestHelpers.create_test_app(
        'test_upgrade_generators_default',
        template: 'upgrade_generators_default_template.rb',
        template_path: template_path
      )
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_upgrade_generators_default'))
    end

    it 'creates the expected v1.7 migration files' do
      within_test_app(app_path) do
        expect(migrations_containing('create_models').any?).to be true
        expect(migrations_containing('migrate_to_ruby_llm_model_references').any?).to be true
      end
    end

    it 'updates existing models acts_as declarations when present' do
      within_test_app(app_path) do
        chat_model = File.read('app/models/chat.rb')
        expect(chat_model).to include('acts_as_chat')
        expect(chat_model).to include('messages_foreign_key')

        message_model = File.read('app/models/message.rb')
        expect(message_model).to include('acts_as_message')
        expect(message_model).to include('tool_calls_foreign_key')

        tool_call_model = File.read('app/models/tool_call.rb')
        expect(tool_call_model).to include('acts_as_tool_call')
        expect(tool_call_model).to include("\n  acts_as_tool_call\n")
      end
    end

    it 'updates existing initializer when present' do
      within_test_app(app_path) do
        initializer = File.read('config/initializers/ruby_llm.rb')
        expect(initializer).to include('RubyLLM.configure')
        expect(initializer).to include('config.use_new_acts_as = true')
      end
    end

    it 'creates the expected v1.9 migration file' do
      within_test_app(app_path) do
        migration_path = migrations_containing('add_ruby_llm_v1_9_columns').first
        expect(migration_path).not_to be_nil

        migration = File.read(migration_path)
        expect(migration).to include('add_column :messages, :cached_tokens')
        expect(migration).to include('add_column :messages, :cache_creation_tokens')
        expect(migration).to include('add_column :messages, :content_raw')
      end
    end
  end

  describe 'with custom model mappings' do
    let(:app_name) { 'test_upgrade_generators_custom_mappings' }
    let(:app_path) { File.join(Dir.tmpdir, app_name) }

    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      template_path = File.expand_path('../../fixtures/templates', __dir__)
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_upgrade_generators_custom_mappings'))
      GeneratorTestHelpers.create_test_app(
        'test_upgrade_generators_custom_mappings',
        template: 'upgrade_generators_custom_mappings_template.rb',
        template_path: template_path
      )
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_upgrade_generators_custom_mappings'))
    end

    it 'creates the expected v1.7 migration files' do
      within_test_app(app_path) do
        expect(migrations_containing('create_models').any?).to be true
        expect(migrations_containing('migrate_to_ruby_llm_model_references').any?).to be true
      end
    end

    it 'respects model mapping args in generated v1.7 migration content' do
      within_test_app(app_path) do
        migration_path = migrations_containing('migrate_to_ruby_llm_model_references').first
        expect(migration_path).not_to be_nil

        migration = File.read(migration_path)
        expect(migration).to include('chat_class = Conversation')
        expect(migration).to include('message_class = ChatMessage')
        expect(migration).to include('collect_and_create_models(chat_class, :conversations, model_class)')
        expect(migration).to include('collect_and_create_models(message_class, :chat_messages, model_class)')
        expect(migration).to include('migrate_foreign_key(:conversations')
        expect(migration).to include('migrate_foreign_key(:chat_messages')
      end
    end

    it 'updates acts_as declarations using mapped table and association names' do
      within_test_app(app_path) do
        conversation_model = File.read('app/models/conversation.rb')
        expect(conversation_model).to include('acts_as_chat')
        expect(conversation_model).to include('messages: :chat_messages')
        expect(conversation_model).to include('messages_foreign_key: :conversation_id')

        chat_message_model = File.read('app/models/chat_message.rb')
        expect(chat_message_model).to include('acts_as_message')
        expect(chat_message_model).to include('chat: :conversation')
        expect(chat_message_model).to include('chat_foreign_key: :conversation_id')
        expect(chat_message_model).to include('tool_calls_foreign_key: :chat_message_id')

        tool_call_model = File.read('app/models/tool_call.rb')
        expect(tool_call_model).to include('acts_as_tool_call')
        expect(tool_call_model).to include('message: :chat_message')
        expect(tool_call_model).to include('message_foreign_key: :chat_message_id')
      end
    end

    it 'creates a v1.9 migration targeting the mapped message table' do
      within_test_app(app_path) do
        migration_path = migrations_containing('add_ruby_llm_v1_9_columns').first
        expect(migration_path).not_to be_nil

        migration = File.read(migration_path)
        expect(migration).to include('add_column :chat_messages, :cached_tokens')
        expect(migration).to include('add_column :chat_messages, :cache_creation_tokens')
        expect(migration).to include('add_column :chat_messages, :content_raw')
      end
    end
  end
end
