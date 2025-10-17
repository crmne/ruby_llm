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

    it 'creates model files with default names' do
      within_test_app(app_path) do
        expect(File.exist?('app/models/chat.rb')).to be true
        expect(File.exist?('app/models/message.rb')).to be true
        expect(File.exist?('app/models/model.rb')).to be true
        expect(File.exist?('app/models/tool_call.rb')).to be true
      end
    end

    it 'creates migration files' do
      within_test_app(app_path) do
        migrations = Dir.glob('db/migrate/*.rb')
        expect(migrations.any? { |f| f.include?('create_chats') }).to be true
        expect(migrations.any? { |f| f.include?('create_messages') }).to be true
        expect(migrations.any? { |f| f.include?('create_tool_calls') }).to be true
        expect(migrations.any? { |f| f.include?('create_models') }).to be true
        expect(migrations.any? { |f| f.include?('add_references_to_chats_tool_calls_and_messages') }).to be true
      end
    end

    it 'creates initializer file' do
      within_test_app(app_path) do
        expect(File.exist?('config/initializers/ruby_llm.rb')).to be true
        initializer = File.read('config/initializers/ruby_llm.rb')
        expect(initializer).to include('RubyLLM.configure')
        expect(initializer).to include('config.use_new_acts_as = true')
        # Default Model class doesn't need explicit config
        expect(initializer).not_to include('config.model_registry_class')
      end
    end

    it 'models have correct acts_as declarations' do
      within_test_app(app_path) do
        chat_model = File.read('app/models/chat.rb')
        expect(chat_model).to include('acts_as_chat')

        message_model = File.read('app/models/message.rb')
        expect(message_model).to include('acts_as_message')

        model_model = File.read('app/models/model.rb')
        expect(model_model).to include('acts_as_model')

        tool_call_model = File.read('app/models/tool_call.rb')
        expect(tool_call_model).to include('acts_as_tool_call')
      end
    end

    it 'chat functionality works correctly' do
      within_test_app(app_path) do
        test_script = <<~RUBY
          chat = Chat.create!
          message = chat.messages.create!(role: :user, content: 'Test')
          exit(message.chat_id == chat.id ? 0 : 1)
        RUBY
        result = system("bundle exec rails runner \"#{test_script.gsub('"', '\"')}\" 2>&1")
        expect(result).to be true
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
        expect(File.exist?('app/models/llm/model.rb')).to be true
        expect(File.exist?('app/models/llm/tool_call.rb')).to be true
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
        expect(migrations.any? { |f| f.include?('create_llm_tool_calls') }).to be true
        expect(migrations.any? { |f| f.include?('create_llm_models') }).to be true
      end
    end

    it 'creates initializer with correct model registry class' do
      within_test_app(app_path) do
        initializer = File.read('config/initializers/ruby_llm.rb')
        expect(initializer).to include('config.model_registry_class = "Llm::Model"')
      end
    end

    it 'models have correct namespaced acts_as declarations' do
      within_test_app(app_path) do
        chat_model = File.read('app/models/llm/chat.rb')
        expect(chat_model).to include('class Llm::Chat')
        expect(chat_model).to include('acts_as_chat messages: :llm_messages')
        expect(chat_model).to include("message_class: 'Llm::Message'")
        expect(chat_model).to include('model: :llm_model')
        expect(chat_model).to include("model_class: 'Llm::Model'")

        message_model = File.read('app/models/llm/message.rb')
        expect(message_model).to include('class Llm::Message')
        expect(message_model).to include('acts_as_message')
        expect(message_model).to include('chat: :llm_chat')
        expect(message_model).to include("chat_class: 'Llm::Chat'")
        expect(message_model).to include('tool_calls: :llm_tool_calls')
        expect(message_model).to include("tool_call_class: 'Llm::ToolCall'")
      end
    end

    it 'namespaced chat functionality works correctly' do
      within_test_app(app_path) do
        test_script = <<~RUBY
          chat = Llm::Chat.create!
          message = chat.llm_messages.create!(role: :user, content: 'Test')
          exit(message.llm_chat_id == chat.id ? 0 : 1)
        RUBY
        result = system("bundle exec rails runner \"#{test_script.gsub('"', '\"')}\" 2>&1")
        expect(result).to be true
      end
    end
  end
end
