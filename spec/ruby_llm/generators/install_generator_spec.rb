# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/install/install_generator'
require_relative '../../support/generator_test_helpers'

RSpec.describe RubyLLM::Generators::InstallGenerator, :generator, type: :generator do
  include GeneratorTestHelpers

  let(:template_path) { File.expand_path('../../fixtures/templates', __dir__) }

  describe 'with default model names' do
    let(:app_name) { 'test_install_default' }
    let(:app_path) { File.join(Dir.tmpdir, app_name) }

    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      template_path = File.expand_path('../../fixtures/templates', __dir__)
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_install_default'))
      GeneratorTestHelpers.create_test_app('test_install_default', template: 'default_models_template.rb',
                                                                   template_path: template_path)
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_install_default'))
    end

    it 'creates only the application-owned model files' do
      within_test_app(app_path) do
        expect(File.exist?('app/models/chat.rb')).to be true
        expect(File.exist?('app/models/message.rb')).to be true
        expect(File.exist?('app/models/model.rb')).to be false
        expect(File.exist?('app/models/tool_call.rb')).to be false
        expect(File.exist?('app/models/batch.rb')).to be false
        expect(File.exist?('app/agents/.gitkeep')).to be true
        expect(File.exist?('app/tools/.gitkeep')).to be true
        expect(File.exist?('app/schemas/.gitkeep')).to be true
        expect(File.exist?('app/prompts/.gitkeep')).to be true
      end
    end

    it 'creates migration files' do
      within_test_app(app_path) do
        migrations = Dir.glob('db/migrate/*.rb')
        expect(migrations.any? { |f| f.include?('create_chats') }).to be true
        expect(migrations.any? { |f| f.include?('create_messages') }).to be true
        expect(migrations.any? { |f| f.include?('create_ruby_llm_records') }).to be true
        expect(migrations.count { |file| !file.include?('active_storage') }).to eq(3)
      end
    end

    it 'adds cancellation state to chat storage' do
      within_test_app(app_path) do
        migration = Dir.glob('db/migrate/*create_chats.rb').first
        expect(migration).to be_present

        content = File.read(migration)
        expect(content).to include('t.boolean :cancelled')
        expect(content).to include('t.references :ruby_llm_model')
        expect(content).to include('foreign_key: { to_table: :ruby_llm_models }')
      end
    end

    it 'creates internal records before the chat foreign key' do
      within_test_app(app_path) do
        migrations = Dir.glob('db/migrate/*.rb').reject { |file| file.include?('active_storage') }.sort

        records_index = migrations.index { |file| file.include?('create_ruby_llm_records') }
        chats_index = migrations.index { |file| file.include?('create_chats') }
        expect(records_index).to be < chats_index
      end
    end

    it 'uses text for tool call thought signatures' do
      within_test_app(app_path) do
        migration = Dir.glob('db/migrate/*create_ruby_llm_records.rb').first
        expect(migration).to be_present

        content = File.read(migration)
        expect(content).to include('t.text :thought_signature')
      end
    end

    it 'adds finish_reason to message storage' do
      within_test_app(app_path) do
        migration = Dir.glob('db/migrate/*create_messages.rb').first
        expect(migration).to be_present

        content = File.read(migration)
        expect(content).to include('t.string :finish_reason')
      end
    end

    it 'adds cache_until_here to message storage' do
      within_test_app(app_path) do
        migration = Dir.glob('db/migrate/*create_messages.rb').first
        expect(migration).to be_present

        content = File.read(migration)
        expect(content).to include('t.boolean :cache_until_here')
      end
    end

    it 'keeps cost and usage tracking out of application message storage' do
      within_test_app(app_path) do
        migration = Dir.glob('db/migrate/*create_messages.rb').first
        content = File.read(migration)

        expect(content).not_to include('input_tokens', 'output_tokens', 'total_cost', 'cost_details')
        expect(content).not_to include('model_id', 'provider')
      end
    end

    it 'keeps internal model-registry migration schema-only' do
      within_test_app(app_path) do
        migration = Dir.glob('db/migrate/*create_ruby_llm_records.rb').first
        expect(migration).to be_present

        content = File.read(migration)
        expect(content).not_to include('Loading models from models.json')
        expect(content).not_to include('save_to_database')
      end
    end

    it 'creates initializer file' do
      within_test_app(app_path) do
        expect(File.exist?('config/initializers/ruby_llm.rb')).to be true
        initializer = File.read('config/initializers/ruby_llm.rb')
        expect(initializer).to include('RubyLLM.configure')
        # use_new_acts_as no longer exists in 2.0; the generator does not emit it
        expect(initializer).not_to include('config.use_new_acts_as')
        # Default Model class doesn't need explicit config
        expect(initializer).not_to include('config.model_registry_class')
      end
    end

    it 'chat and message have the only acts_as declarations' do
      within_test_app(app_path) do
        chat_model = File.read('app/models/chat.rb')
        expect(chat_model).to include('acts_as_chat')

        message_model = File.read('app/models/message.rb')
        expect(message_model).to include('acts_as_message')

        expect(chat_model).not_to include('model_class')
        expect(message_model).not_to include('tool_call_class')
      end
    end

    it 'chat functionality works correctly' do
      within_test_app(app_path) do
        test_script = <<~RUBY
          chat = Chat.create!
          message = chat.messages.create!(role: :user, content: 'Test')
          exit(message.chat_id == chat.id ? 0 : 1)
        RUBY
        success, output = run_rails_runner(test_script)
        expect(success).to be(true), output
      end
    end
  end

  describe 'with namespaced model names' do
    let(:app_name) { 'test_install_namespaced' }
    let(:app_path) { File.join(Dir.tmpdir, app_name) }

    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      template_path = File.expand_path('../../fixtures/templates', __dir__)
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_install_namespaced'))
      GeneratorTestHelpers.create_test_app('test_install_namespaced', template: 'namespaced_models_template.rb',
                                                                      template_path: template_path)
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_install_namespaced'))
    end

    it 'creates namespaced model files' do
      within_test_app(app_path) do
        expect(File.exist?('app/models/llm.rb')).to be true
        expect(File.exist?('app/models/llm/chat.rb')).to be true
        expect(File.exist?('app/models/llm/message.rb')).to be true
        expect(File.exist?('app/models/llm/model.rb')).to be false
        expect(File.exist?('app/models/llm/tool_call.rb')).to be false
      end
    end

    it 'creates namespace module file' do
      within_test_app(app_path) do
        module_file = File.read('app/models/llm.rb')
        expect(module_file).to include('module Llm')
        expect(module_file).to include('def self.table_name_prefix')
        expect(module_file).to include('"llm_"')
      end
    end

    it 'creates migrations with namespaced table names' do
      within_test_app(app_path) do
        migrations = Dir.glob('db/migrate/*.rb')
        expect(migrations.any? { |f| f.include?('create_llm_chats') }).to be true
        expect(migrations.any? { |f| f.include?('create_llm_messages') }).to be true
        expect(migrations.any? { |f| f.include?('create_ruby_llm_records') }).to be true
      end
    end

    it 'keeps the internal registry out of the initializer' do
      within_test_app(app_path) do
        initializer = File.read('config/initializers/ruby_llm.rb')
        expect(initializer).not_to include('model_registry_class')
      end
    end

    it 'models have correct namespaced acts_as declarations' do
      within_test_app(app_path) do
        chat_model = File.read('app/models/llm/chat.rb')
        expect(chat_model).to include('class Llm::Chat')
        expect(chat_model).to include('acts_as_chat messages: :llm_messages')
        expect(chat_model).to include("message_class: 'Llm::Message'")
        expect(chat_model).not_to include('model_class')

        message_model = File.read('app/models/llm/message.rb')
        expect(message_model).to include('class Llm::Message')
        expect(message_model).to include('acts_as_message')
        expect(message_model).to include('chat: :llm_chat')
        expect(message_model).to include("chat_class: 'Llm::Chat'")
        expect(message_model).not_to include('tool_call_class')
      end
    end

    it 'namespaced chat functionality works correctly' do
      within_test_app(app_path) do
        test_script = <<~RUBY
          chat = Llm::Chat.create!
          message = chat.llm_messages.create!(role: :user, content: 'Test')
          exit(message.llm_chat_id == chat.id ? 0 : 1)
        RUBY
        success, output = run_rails_runner(test_script)
        expect(success).to be(true), output
      end
    end

    it 'namespaced messages use RubyLLM internal polymorphic records' do
      within_test_app(app_path) do
        test_script = <<~RUBY
          chat = Llm::Chat.create!
          tool_call_message = chat.llm_messages.create!(role: :assistant, content: nil)
          tool_call = tool_call_message.ruby_llm_tool_calls.create!(
            tool_call_id: 'call_1',
            name: 'calculator',
            arguments: { expression: '2 + 2' }
          )
          tool_result = chat.llm_messages.create!(role: :tool, content: '4')
          tool_call.update!(result: tool_result)

          exit(tool_result.parent_tool_call.id == 'call_1' && tool_call.result == tool_result ? 0 : 1)
        RUBY
        success, output = run_rails_runner(test_script)
        expect(success).to be(true), output
      end
    end
  end
end
