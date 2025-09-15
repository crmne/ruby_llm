# frozen_string_literal: true

require 'rails_helper'
require 'fileutils'
require 'generators/ruby_llm/install/install_generator'

RSpec.describe RubyLLM::InstallGenerator, type: :generator do
  # Use the actual template directory
  let(:template_dir) { File.join(__dir__, '../../../../lib/generators/ruby_llm/install/templates') }
  let(:generator_file) { File.join(__dir__, '../../../../lib/generators/ruby_llm/install/install_generator.rb') }

  describe 'migration templates' do
    let(:expected_migration_files) do
      [
        'create_chats_migration.rb.tt',
        'create_messages_migration.rb.tt',
        'create_tool_calls_migration.rb.tt',
        'create_models_migration.rb.tt',
        'add_references_to_chats_tool_calls_and_messages_migration.rb.tt'
      ]
    end

    it 'has all required migration template files' do
      expected_migration_files.each do |file|
        expect(File.exist?(File.join(template_dir, file))).to be(true)
      end
    end

    describe 'chats migration' do
      let(:chat_migration) { File.read(File.join(template_dir, 'create_chats_migration.rb.tt')) }

      it 'defines chats table' do
        expect(chat_migration).to include('create_table :<%= chat_table_name %>')
      end
    end

    describe 'messages migration' do
      let(:message_migration) { File.read(File.join(template_dir, 'create_messages_migration.rb.tt')) }

      it 'defines messages table' do
        expect(message_migration).to include('create_table :<%= message_table_name %>')
      end

      it 'includes role field' do
        expect(message_migration).to include('t.string :role')
      end

      it 'includes content field' do
        expect(message_migration).to include('t.text :content')
      end
    end

    describe 'tool_calls migration' do
      let(:tool_call_migration) { File.read(File.join(template_dir, 'create_tool_calls_migration.rb.tt')) }

      it 'defines tool_calls table' do
        expect(tool_call_migration).to include('create_table :<%= tool_call_table_name %>')
      end

      it 'includes tool_call_id field' do
        expect(tool_call_migration).to include('t.string :tool_call_id')
      end

      it 'includes name field' do
        expect(tool_call_migration).to include('t.string :name')
      end
    end

    describe 'add references migration' do
      let(:add_references_migration) do
        File.read(File.join(template_dir, 'add_references_to_chats_tool_calls_and_messages_migration.rb.tt'))
      end

      it 'adds model reference to chats' do
        expect(add_references_migration).to include('add_reference :<%= chat_table_name %>, ' \
                                                    ':<%= model_table_name.singularize %>, foreign_key: true')
      end

      it 'adds message reference to tool_calls' do
        expect(add_references_migration).to include('add_reference :<%= tool_call_table_name %>, ' \
                                                    ':<%= message_table_name.singularize %>, ' \
                                                    'null: false, foreign_key: true')
      end

      it 'adds chat reference to messages' do
        expect(add_references_migration).to include('add_reference :<%= message_table_name %>, ' \
                                                    ':<%= chat_table_name.singularize %>, ' \
                                                    'null: false, foreign_key: true')
      end

      it 'adds model reference to messages' do
        expect(add_references_migration).to include('add_reference :<%= message_table_name %>, ' \
                                                    ':<%= model_table_name.singularize %>, foreign_key: true')
      end

      it 'adds tool_call reference to messages' do
        expect(add_references_migration).to include('add_reference :<%= message_table_name %>, ' \
                                                    ':<%= tool_call_table_name.singularize %>, foreign_key: true')
      end
    end
  end

  describe 'JSON handling in migrations' do
    let(:tool_call_migration) { File.read(File.join(template_dir, 'create_tool_calls_migration.rb.tt')) }

    describe 'PostgreSQL support' do
      it 'includes postgresql condition check' do
        expect(tool_call_migration).to include("t.<%= postgresql? ? 'jsonb' : 'json' %> :arguments, default: {}")
      end
    end
  end

  describe 'model templates' do
    let(:expected_model_files) do
      [
        'chat_model.rb.tt',
        'message_model.rb.tt',
        'tool_call_model.rb.tt',
        'model_model.rb.tt'
      ]
    end

    it 'has all required model template files' do
      expected_model_files.each do |file|
        expect(File.exist?(File.join(template_dir, file))).to be(true)
      end
    end

    it 'declares acts_as_chat in chat model' do
      chat_content = File.read(File.join(template_dir, 'chat_model.rb.tt'))
      expect(chat_content).to include('acts_as_chat')
    end

    it 'declares acts_as_message in message model' do
      message_content = File.read(File.join(template_dir, 'message_model.rb.tt'))
      expect(message_content).to include('acts_as_message')
    end

    it 'declares acts_as_tool_call in tool call model' do
      tool_call_content = File.read(File.join(template_dir, 'tool_call_model.rb.tt'))
      expect(tool_call_content).to include('acts_as_tool_call')
    end

    it 'declares acts_as_model in model model' do
      model_content = File.read(File.join(template_dir, 'model_model.rb.tt'))
      expect(model_content).to include('acts_as_model')
    end
  end

  describe 'models migration' do
    let(:models_migration) { File.read(File.join(template_dir, 'create_models_migration.rb.tt')) }

    it 'defines models table' do
      expect(models_migration).to include('create_table :<%= model_table_name %>')
    end

    it 'includes model_id field' do
      expect(models_migration).to include('t.string :model_id')
    end

    it 'includes provider field' do
      expect(models_migration).to include('t.string :provider')
    end

    it 'includes unique index on provider and model_id' do
      expect(models_migration).to include('t.index [:provider, :model_id], unique: true')
    end

    it 'supports jsonb for PostgreSQL' do
      expect(models_migration).to include('t.jsonb :modalities')
      expect(models_migration).to include('t.jsonb :capabilities')
      expect(models_migration).to include('t.jsonb :pricing')
      expect(models_migration).to include('t.json :modalities')
      expect(models_migration).to include('t.json :capabilities')
      expect(models_migration).to include('t.json :pricing')
    end
  end

  describe 'initializer template' do
    let(:initializer_content) { File.read(File.join(template_dir, 'initializer.rb.tt')) }

    it 'has initializer template file' do
      expect(File.exist?(File.join(template_dir, 'initializer.rb.tt'))).to be(true)
    end

    it 'includes RubyLLM configuration block' do
      expect(initializer_content).to include('RubyLLM.configure do |config|')
    end

    it 'configures OpenAI API key' do
      expect(initializer_content).to include('config.openai_api_key')
    end

    it 'configures model registry class' do
      expect(initializer_content).to include('config.model_registry_class')
    end
  end

  describe 'show_install_info method' do
    let(:generator_content) { File.read(generator_file) }

    it 'defines show_install_info method' do
      expect(generator_content).to include('def show_install_info')
    end

    it 'includes welcome message' do
      expect(generator_content).to include('RubyLLM installed!')
    end

    it 'includes migration instructions' do
      expect(generator_content).to include('rails db:migrate')
    end

    it 'includes API configuration instructions' do
      expect(generator_content).to include('Set your API keys')
    end

    it 'includes usage example with create! and ask' do
      expect(generator_content).to include('.create!(model:').and include('.ask(')
    end

    it 'includes documentation link' do
      expect(generator_content).to include('https://rubyllm.com')
    end
  end

  describe 'generator structure' do
    let(:generator_content) { File.read(generator_file) }

    it 'has generator file' do
      expect(File.exist?(generator_file)).to be(true)
    end

    it 'inherits from Rails::Generators::Base' do
      expect(generator_content).to include('class InstallGenerator < Rails::Generators::Base')
    end

    it 'includes Rails::Generators::Migration' do
      expect(generator_content).to include('include Rails::Generators::Migration')
    end
  end

  describe 'generator methods' do
    let(:generator_content) { File.read(generator_file) }

    it 'defines create_migration_files method' do
      expect(generator_content).to include('def create_migration_files')
    end

    it 'defines create_model_files method' do
      expect(generator_content).to include('def create_model_files')
    end

    it 'defines create_initializer method' do
      expect(generator_content).to include('def create_initializer')
    end

    it 'defines show_install_info method' do
      expect(generator_content).to include('def show_install_info')
    end
  end

  describe 'migration order' do
    let(:generator_content) { File.read(generator_file) }

    it 'creates migrations in correct order' do
      migration_section = generator_content[/def create_migration_files.*?\n    end/m]

      # Look for the table name references which are in the migration paths
      chats_position = migration_section.index('chat_table_name')
      messages_position = migration_section.index('message_table_name')
      tool_calls_position = migration_section.index('tool_call_table_name')
      models_position = migration_section.index('model_table_name')

      expect(chats_position).not_to be_nil
      expect(messages_position).not_to be_nil
      expect(tool_calls_position).not_to be_nil

      expect(chats_position).to be < messages_position
      expect(messages_position).to be < tool_calls_position

      # Models migration should come last if present
      expect(models_position).to be > tool_calls_position if models_position
    end

    it 'adds references after creating all tables' do
      migration_section = generator_content[/def create_migration_files.*?\n    end/m]

      add_references_position = migration_section.index(
        'add_references_to_chats_tool_calls_and_messages_migration.rb.tt'
      )
      models_position = migration_section.index('model_table_name')

      expect(add_references_position).not_to be_nil
      expect(models_position).not_to be_nil

      expect(add_references_position).to be > models_position
    end
  end

  describe '#postgresql?' do
    subject(:generator) { described_class.new }

    context 'when using PostgreSQL' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:adapter_name).and_return('PostgreSQL')
      end

      it 'returns true' do
        expect(generator.postgresql?).to be true
      end
    end

    context 'when using MySQL' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:adapter_name).and_return('MySQL')
      end

      it 'returns false' do
        expect(generator.postgresql?).to be false
      end
    end

    context 'when ActiveRecord is not loaded' do
      before do
        allow(ActiveRecord::Base).to receive(:connection).and_raise(NameError)
      end

      it 'returns false' do
        expect(generator.postgresql?).to be false
      end
    end

    context 'when database connection fails' do
      before do
        allow(ActiveRecord::Base).to receive(:connection).and_raise(ActiveRecord::ConnectionNotEstablished)
      end

      it 'returns false' do
        expect(generator.postgresql?).to be false
      end
    end
  end
end
