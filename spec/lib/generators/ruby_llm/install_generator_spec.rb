# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/install_generator'

RSpec.describe RubyLLM::InstallGenerator, type: :generator do
  # Use the actual template directory
  let(:template_dir) { File.join(__dir__, '../../../../lib/generators/ruby_llm/install/templates') }
  let(:generator_file) { File.join(__dir__, '../../../../lib/generators/ruby_llm/install_generator.rb') }

  describe 'migration templates' do
    let(:expected_migration_files) do
      [
        'create_chats_migration.rb.tt',
        'create_messages_migration.rb.tt',
        'create_tool_calls_migration.rb.tt'
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
        expect(chat_migration).to include('create_table :<%= options[:chat_model_name].tableize %>')
      end

      it 'includes model_id field' do
        expect(chat_migration).to include('t.string :model_id')
      end
    end

    describe 'messages migration' do
      let(:message_migration) { File.read(File.join(template_dir, 'create_messages_migration.rb.tt')) }

      it 'defines messages table' do
        expect(message_migration).to include('create_table :<%= options[:message_model_name].tableize %>')
      end

      it 'includes chat reference' do
        expect(message_migration).to include('t.references :<%= options[:chat_model_name].tableize.singularize %>, null: false, foreign_key: true')
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
        expect(tool_call_migration).to include('create_table :<%= options[:tool_call_model_name].tableize %>')
      end

      it 'includes tool_call_id field' do
        expect(tool_call_migration).to include('t.string :tool_call_id')
      end

      it 'includes name field' do
        expect(tool_call_migration).to include('t.string :name')
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
        'tool_call_model.rb.tt'
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

    it 'configures Anthropic API key' do
      expect(initializer_content).to include('config.anthropic_api_key')
    end
  end

  describe 'README template' do
    let(:readme_content) { File.read(File.join(template_dir, 'README.md.tt')) }

    it 'has README template file' do
      expect(File.exist?(File.join(template_dir, 'README.md.tt'))).to be(true)
    end

    it 'includes welcome message' do
      expect(readme_content).to include('RubyLLM Rails Setup Complete')
    end

    it 'includes setup information' do
      expect(readme_content).to include('Run migrations')
    end

    it 'includes migration instructions' do
      expect(readme_content).to include('rails db:migrate')
    end

    it 'includes API configuration instructions' do
      expect(readme_content).to include('Set your API keys')
    end

    it 'includes usage examples' do
      expect(readme_content).to include('Start using RubyLLM in your code')
    end

    it 'includes streaming response information' do
      expect(readme_content).to include('For streaming responses')
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

    it 'defines show_readme method' do
      expect(generator_content).to include('def show_readme')
    end
  end

  describe 'database detection' do
    let(:generator_content) { File.read(generator_file) }

    it 'defines postgresql? method' do
      expect(generator_content).to include('def postgresql?')
    end

    it 'detects PostgreSQL adapter' do
      expect(generator_content).to include('ActiveRecord::Base.connection.adapter_name.downcase.include?')
    end

    it 'includes rescue block for error handling' do
      expect(generator_content).to include('rescue')
    end

    it 'returns false on error' do
      expect(generator_content).to include('false')
    end
  end
end
