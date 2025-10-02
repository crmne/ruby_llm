# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/chat_ui/chat_ui_generator'
require_relative '../../support/generator_test_helpers'

RSpec.describe RubyLLM::Generators::ChatUIGenerator, :generator, type: :generator do
  include GeneratorTestHelpers

  let(:rails_root) { Rails.root }
  let(:template_path) { File.expand_path('../../fixtures/templates', __dir__) }

  describe 'with default model names' do
    let(:app_name) { 'test_app_default' }
    let(:app_path) { File.join(Dir.tmpdir, app_name) }

    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      template_path = File.expand_path('../../fixtures/templates', __dir__)
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_app_default'))
      GeneratorTestHelpers.create_test_app('test_app_default',
                                           template: 'default_models_template.rb',
                                           template_path: template_path)
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_app_default'))
    end

    it 'creates controller files with default names' do
      within_test_app(app_path) do
        expect(File.exist?('app/controllers/chats_controller.rb')).to be true
        expect(File.exist?('app/controllers/messages_controller.rb')).to be true
        expect(File.exist?('app/controllers/models_controller.rb')).to be true
      end
    end

    it 'creates view files with default paths' do
      within_test_app(app_path) do
        # Chat views
        expect(File.exist?('app/views/chats/index.html.erb')).to be true
        expect(File.exist?('app/views/chats/new.html.erb')).to be true
        expect(File.exist?('app/views/chats/show.html.erb')).to be true
        expect(File.exist?('app/views/chats/_chat.html.erb')).to be true
        expect(File.exist?('app/views/chats/_form.html.erb')).to be true

        # Message views
        expect(File.exist?('app/views/messages/_message.html.erb')).to be true
        expect(File.exist?('app/views/messages/_content.html.erb')).to be true
        expect(File.exist?('app/views/messages/_form.html.erb')).to be true
        expect(File.exist?('app/views/messages/create.turbo_stream.erb')).to be true

        # Model views
        expect(File.exist?('app/views/models/index.html.erb')).to be true
        expect(File.exist?('app/views/models/show.html.erb')).to be true
        expect(File.exist?('app/views/models/_model.html.erb')).to be true
      end
    end

    it 'creates job file with default name' do
      within_test_app(app_path) do
        expect(File.exist?('app/jobs/chat_response_job.rb')).to be true
      end
    end

    it 'adds routes for default controllers' do
      within_test_app(app_path) do
        routes_content = File.read('config/routes.rb')
        expect(routes_content).to include('resources :chats')
        expect(routes_content).to include('resources :messages, only: [:create]')
        expect(routes_content).to include('resources :models, only: [:index, :show]')
      end
    end

    it 'adds broadcasting to message model' do
      within_test_app(app_path) do
        message_content = File.read('app/models/message.rb')

        # Check the acts_as_message declaration
        expect(message_content).to include('acts_as_message')

        # Check broadcasting setup
        expect(message_content).to include('broadcasts_to ->(message) { "chat_#{message.chat_id}" }')

        # Check broadcast_append_chunk method
        expect(message_content).to include('def broadcast_append_chunk(content)')
        expect(message_content).to include('broadcast_append_to "chat_#{chat_id}"')
        expect(message_content).to include('target: "message_#{id}_content"')
        expect(message_content).to include('partial: "messages/content"')
      end
    end

    it 'controllers reference correct model classes' do
      within_test_app(app_path) do
        chats_controller = File.read('app/controllers/chats_controller.rb')
        expect(chats_controller).to include('class ChatsController')
        expect(chats_controller).to include('Chat.find')
        expect(chats_controller).to include('@chat = Chat.new')
        expect(chats_controller).to include('@chat = Chat.create!(model: model)')

        messages_controller = File.read('app/controllers/messages_controller.rb')
        expect(messages_controller).to include('class MessagesController')
        expect(messages_controller).to include('@chat = Chat.find(params[:chat_id])')
        expect(messages_controller).to include('ChatResponseJob.perform_later')

        models_controller = File.read('app/controllers/models_controller.rb')
        expect(models_controller).to include('class ModelsController')
        expect(models_controller).to include('@models = Model.all')
      end
    end

    it 'job references correct model classes' do
      within_test_app(app_path) do
        job_content = File.read('app/jobs/chat_response_job.rb')
        expect(job_content).to include('class ChatResponseJob')
        expect(job_content).to include('chat = Chat.find(chat_id)')
        expect(job_content).to include('chat.ask(content)')
        expect(job_content).to include('message = chat.messages.last')
      end
    end

    it 'chat functionality works correctly' do
      within_test_app(app_path) do
        test_script = <<~RUBY
          ActiveJob::Base.queue_adapter = :inline
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
    let(:app_name) { 'test_app_namespaced' }
    let(:app_path) { File.join(Dir.tmpdir, app_name) }

    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      template_path = File.expand_path('../../fixtures/templates', __dir__)
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_app_namespaced'))
      GeneratorTestHelpers.create_test_app('test_app_namespaced', template: 'namespaced_models_template.rb',
                                                                  template_path: template_path)
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_app_namespaced'))
    end

    it 'creates controller files with namespaced paths' do
      within_test_app(app_path) do
        expect(File.exist?('app/controllers/llm/chats_controller.rb')).to be true
        expect(File.exist?('app/controllers/llm/messages_controller.rb')).to be true
        expect(File.exist?('app/controllers/llm/models_controller.rb')).to be true
      end
    end

    it 'creates view files with namespaced paths' do
      within_test_app(app_path) do
        # Chat views
        expect(File.exist?('app/views/llm/chats/index.html.erb')).to be true
        expect(File.exist?('app/views/llm/chats/new.html.erb')).to be true
        expect(File.exist?('app/views/llm/chats/show.html.erb')).to be true
        expect(File.exist?('app/views/llm/chats/_chat.html.erb')).to be true
        expect(File.exist?('app/views/llm/chats/_form.html.erb')).to be true

        # Message views
        expect(File.exist?('app/views/llm/messages/_message.html.erb')).to be true
        expect(File.exist?('app/views/llm/messages/_content.html.erb')).to be true
        expect(File.exist?('app/views/llm/messages/_form.html.erb')).to be true
        expect(File.exist?('app/views/llm/messages/create.turbo_stream.erb')).to be true

        # Model views
        expect(File.exist?('app/views/llm/models/index.html.erb')).to be true
        expect(File.exist?('app/views/llm/models/show.html.erb')).to be true
        expect(File.exist?('app/views/llm/models/_model.html.erb')).to be true
      end
    end

    it 'creates job file with namespaced name' do
      within_test_app(app_path) do
        expect(File.exist?('app/jobs/llm_chat_response_job.rb')).to be true
      end
    end

    it 'adds routes for namespaced controllers' do
      within_test_app(app_path) do
        routes_content = File.read('config/routes.rb')
        expect(routes_content).to include('namespace :llm')
        expect(routes_content).to include('resources :chats')
        expect(routes_content).to include('resources :messages, only: [:create]')
        expect(routes_content).to include('resources :models, only: [:index, :show]')
      end
    end

    it 'adds broadcasting to namespaced message model' do
      within_test_app(app_path) do
        message_content = File.read('app/models/llm/message.rb')

        # Check the acts_as_message declaration
        expect(message_content).to include("acts_as_message chat: :llm_chat, chat_class: 'Llm::Chat'")
        expect(message_content).to include("tool_calls: :llm_tool_calls, tool_call_class: 'Llm::ToolCall'")
        expect(message_content).to include("model: :llm_model, model_class: 'Llm::Model'")

        # Check broadcasting setup
        expect(message_content).to include('broadcasts_to ->(llm_message) { "llm_chat_#{llm_message.llm_chat_id}" }')
        expect(message_content).to include('partial: "llm/messages/message"')
        # Broadcasting with namespaced models uses partial path without explicit locals

        # Check broadcast_append_chunk method
        expect(message_content).to include('def broadcast_append_chunk(content)')
        expect(message_content).to include('broadcast_append_to "llm_chat_#{llm_chat_id}"')
        expect(message_content).to include('target: "llm_message_#{id}_content"')
        expect(message_content).to include('partial: "llm/messages/content"')
      end
    end

    it 'controllers reference correct namespaced model classes' do
      within_test_app(app_path) do
        chats_controller = File.read('app/controllers/llm/chats_controller.rb')
        expect(chats_controller).to include('class Llm::ChatsController')
        expect(chats_controller).to include('Llm::Chat.find')
        expect(chats_controller).to include('@llm_chat = Llm::Chat.new')
        expect(chats_controller).to include('@llm_chat = Llm::Chat.create!(model: model)')

        messages_controller = File.read('app/controllers/llm/messages_controller.rb')
        expect(messages_controller).to include('class Llm::MessagesController')
        expect(messages_controller).to include('@llm_chat = Llm::Chat.find(params[:chat_id])')
        expect(messages_controller).to include('LlmChatResponseJob.perform_later')

        models_controller = File.read('app/controllers/llm/models_controller.rb')
        expect(models_controller).to include('class Llm::ModelsController')
        expect(models_controller).to include('@llm_models = Llm::Model.all')
      end
    end

    it 'job references correct namespaced model classes' do
      within_test_app(app_path) do
        job_content = File.read('app/jobs/llm_chat_response_job.rb')
        expect(job_content).to include('class LlmChatResponseJob')
        expect(job_content).to include('llm_chat = Llm::Chat.find(llm_chat_id)')
        expect(job_content).to include('llm_chat.ask(content)')
        expect(job_content).to include('llm_message = llm_chat.llm_messages.last')
      end
    end

    it 'views use correct partial paths' do
      within_test_app(app_path) do
        show_view = File.read('app/views/llm/chats/show.html.erb')
        expect(show_view).to include('render')
        expect(show_view).to include('render "llm/messages/form"')
        expect(show_view).to include('llm_message: @llm_message')
        expect(show_view).to include('llm_chat: @llm_chat')

        # Check that variable names are correct (no slashes in variable names, but OK in paths)
        expect(show_view).not_to include('llm/message:')
        expect(show_view).not_to include('@llm/message')
        expect(show_view).not_to include('llm/chat')

        index_view = File.read('app/views/llm/chats/index.html.erb')
        expect(index_view).to include('render llm_chat')
        expect(index_view).to include('@llm_chats.each do |llm_chat|')
      end
    end

    it 'namespaced chat functionality works correctly' do
      within_test_app(app_path) do
        test_script = <<~RUBY
          ActiveJob::Base.queue_adapter = :inline
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
