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
        expect(File.exist?('app/helpers/messages_helper.rb')).to be true

        messages_helper = File.read('app/helpers/messages_helper.rb')
        expect(messages_helper).to include('def default_model_display_name')
        expect(messages_helper).to include('def llm_model_label(model)')
        expect(messages_helper).not_to include('def model_display_name(model)')
        expect(messages_helper).not_to include('def provider_display_name(model_or_provider)')
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
        expect(File.exist?('app/views/messages/_assistant.html.erb')).to be true
        expect(File.exist?('app/views/messages/_user.html.erb')).to be true
        expect(File.exist?('app/views/messages/_system.html.erb')).to be true
        expect(File.exist?('app/views/messages/_tool.html.erb')).to be true
        expect(File.exist?('app/views/messages/_error.html.erb')).to be true
        expect(File.exist?('app/views/messages/_content.html.erb')).to be true
        expect(File.exist?('app/views/messages/_tool_calls.html.erb')).to be true
        expect(File.exist?('app/views/messages/tool_calls/_default.html.erb')).to be true
        expect(File.exist?('app/views/messages/tool_results/_default.html.erb')).to be true
        expect(File.exist?('app/views/messages/create.turbo_stream.erb')).to be true
        expect(File.exist?('app/views/messages/update.turbo_stream.erb')).to be true
        expect(File.exist?('app/views/messages/_form.html.erb')).to be true

        user_partial = File.read('app/views/messages/_user.html.erb')
        expect(user_partial).to include('user.content')
        expect(user_partial).not_to include('local_assigns[')
        assistant_partial = File.read('app/views/messages/_assistant.html.erb')
        expect(assistant_partial).to include('assistant.content')
        expect(assistant_partial).not_to include('local_assigns[')
        system_partial = File.read('app/views/messages/_system.html.erb')
        expect(system_partial).to include('system.content')
        expect(system_partial).not_to include('local_assigns[')
        tool_partial = File.read('app/views/messages/_tool.html.erb')
        expect(tool_partial).to include('render tool_result_partial(tool), tool: tool')
        tool_calls_partial = File.read('app/views/messages/_tool_calls.html.erb')
        expect(tool_calls_partial).to include('tool_calls: tool_calls, tool_call: tool_call')
        expect(tool_calls_partial).not_to include('local_assigns[')
        chat_form = File.read('app/views/chats/_form.html.erb')
        expect(chat_form).to include('@chat_models.map')
        expect(chat_form).to include('llm_model_label(model)')
        expect(chat_form).to include('default_model_display_name')
        create_stream = File.read('app/views/messages/create.turbo_stream.erb')
        expect(create_stream).to include('turbo_stream.replace "new_message"')
        expect(create_stream).to include('render "messages/form"')

        # Model views
        expect(File.exist?('app/views/models/index.html.erb')).to be true
        expect(File.exist?('app/views/models/show.html.erb')).to be true
        expect(File.exist?('app/views/models/_model.html.erb')).to be true
        models_index = File.read('app/views/models/index.html.erb')
        expect(models_index).to include('@models.each do |model_info|')
        expect(models_index).to include('render "models/model",')
      end
    end

    it 'uses scaffold-style inline styles by default' do
      within_test_app(app_path) do
        index_view = File.read('app/views/chats/index.html.erb')
        expect(index_view).to include('<p style="color: green">')
        expect(index_view).not_to include('text-green-700')
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
        expect(routes_content).to include('resources :messages, only: [ :create ]')
        expect(routes_content).to include('resources :models, only: [ :index, :show ]')
      end
    end

    it 'adds broadcasting to message model' do
      within_test_app(app_path) do
        message_content = File.read('app/models/message.rb')

        # Check the acts_as_message declaration
        expect(message_content).to include('acts_as_message')

        # Check broadcasting setup
        expect(message_content).to include('after_create_commit :broadcast_message_created')
        expect(message_content).to include('after_update_commit :broadcast_message_updated')
        expect(message_content).to include('after_destroy_commit :broadcast_message_removed')
        expect(message_content).to include('template: "messages/create"')
        expect(message_content).to include('template: "messages/update"')
        expect(message_content).to include('locals: { message: self }')

        # Check broadcast_append_chunk method
        expect(message_content).to include('def broadcast_append_chunk(content)')
        expect(message_content).to include(%q(broadcast_append_to "chat_#{chat_id}"))
        expect(message_content).to include(%q(target: "message_#{id}_content"))
        expect(message_content).to include('content: ERB::Util.html_escape(content.to_s)')
      end
    end

    it 'controllers reference correct model classes' do
      within_test_app(app_path) do
        chats_controller = File.read('app/controllers/chats_controller.rb')
        expect(chats_controller).to include('class ChatsController')
        expect(chats_controller).to include('Chat.find')
        expect(chats_controller).to include('@chat = Chat.new')
        expect(chats_controller).to include('@chat_models = RubyLLM.models.chat_models.all')
        expect(chats_controller).to include('@chat = Chat.create!(model: model)')

        messages_controller = File.read('app/controllers/messages_controller.rb')
        expect(messages_controller).to include('class MessagesController')
        expect(messages_controller).to include('@chat = Chat.find(params[:chat_id])')
        expect(messages_controller).to include('ChatResponseJob.perform_later')
        expect(messages_controller).to include('format.turbo_stream')

        models_controller = File.read('app/controllers/models_controller.rb')
        expect(models_controller).to include('class ModelsController')
        expect(models_controller).to include('@models = RubyLLM.models.chat_models.all')
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
        success, output = run_rails_runner(test_script)
        expect(success).to be(true), output
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
        expect(File.exist?('app/helpers/llm/messages_helper.rb')).to be true

        messages_helper = File.read('app/helpers/llm/messages_helper.rb')
        expect(messages_helper).to include('def default_model_display_name')
        expect(messages_helper).to include('def llm_model_label(model)')
        expect(messages_helper).not_to include('def model_display_name(model)')
        expect(messages_helper).not_to include('def provider_display_name(model_or_provider)')
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
        expect(File.exist?('app/views/llm/messages/_assistant.html.erb')).to be true
        expect(File.exist?('app/views/llm/messages/_user.html.erb')).to be true
        expect(File.exist?('app/views/llm/messages/_system.html.erb')).to be true
        expect(File.exist?('app/views/llm/messages/_tool.html.erb')).to be true
        expect(File.exist?('app/views/llm/messages/_error.html.erb')).to be true
        expect(File.exist?('app/views/llm/messages/_content.html.erb')).to be true
        expect(File.exist?('app/views/llm/messages/_tool_calls.html.erb')).to be true
        expect(File.exist?('app/views/llm/messages/tool_calls/_default.html.erb')).to be true
        expect(File.exist?('app/views/llm/messages/tool_results/_default.html.erb')).to be true
        expect(File.exist?('app/views/llm/messages/create.turbo_stream.erb')).to be true
        expect(File.exist?('app/views/llm/messages/update.turbo_stream.erb')).to be true
        expect(File.exist?('app/views/llm/messages/_form.html.erb')).to be true

        user_partial = File.read('app/views/llm/messages/_user.html.erb')
        expect(user_partial).to include('user.content')
        expect(user_partial).not_to include('local_assigns[')
        assistant_partial = File.read('app/views/llm/messages/_assistant.html.erb')
        expect(assistant_partial).to include('assistant.content')
        expect(assistant_partial).not_to include('local_assigns[')
        system_partial = File.read('app/views/llm/messages/_system.html.erb')
        expect(system_partial).to include('system.content')
        expect(system_partial).not_to include('local_assigns[')
        tool_partial = File.read('app/views/llm/messages/_tool.html.erb')
        expect(tool_partial).to include('render tool_result_partial(tool), tool: tool')
        tool_calls_partial = File.read('app/views/llm/messages/_tool_calls.html.erb')
        expect(tool_calls_partial).to include('tool_calls: tool_calls, tool_call: tool_call')
        expect(tool_calls_partial).not_to include('local_assigns[')
        chat_form = File.read('app/views/llm/chats/_form.html.erb')
        expect(chat_form).to include('@chat_models.map')
        expect(chat_form).to include('llm_model_label(model)')
        expect(chat_form).to include('default_model_display_name')
        create_stream = File.read('app/views/llm/messages/create.turbo_stream.erb')
        expect(create_stream).to include('turbo_stream.replace "new_llm_message"')
        expect(create_stream).to include('render "llm/messages/form"')

        # Model views
        expect(File.exist?('app/views/llm/models/index.html.erb')).to be true
        expect(File.exist?('app/views/llm/models/show.html.erb')).to be true
        expect(File.exist?('app/views/llm/models/_model.html.erb')).to be true
        models_index = File.read('app/views/llm/models/index.html.erb')
        expect(models_index).to include('@llm_models.each do |model_info|')
        expect(models_index).to include('render "llm/models/model",')
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
        expect(routes_content).to include('resources :messages, only: [ :create ]')
        expect(routes_content).to include('resources :models, only: [ :index, :show ]')
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
        expect(message_content).to include('after_create_commit :broadcast_message_created')
        expect(message_content).to include('after_update_commit :broadcast_message_updated')
        expect(message_content).to include('after_destroy_commit :broadcast_message_removed')
        expect(message_content).to include('template: "llm/messages/create"')
        expect(message_content).to include('template: "llm/messages/update"')
        expect(message_content).to include('locals: { llm_message: self }')

        # Check broadcast_append_chunk method
        expect(message_content).to include('def broadcast_append_chunk(content)')
        expect(message_content).to include(%q(broadcast_append_to "llm_chat_#{llm_chat_id}"))
        expect(message_content).to include(%q(target: "llm_message_#{id}_content"))
        expect(message_content).to include('content: ERB::Util.html_escape(content.to_s)')
      end
    end

    it 'controllers reference correct namespaced model classes' do
      within_test_app(app_path) do
        chats_controller = File.read('app/controllers/llm/chats_controller.rb')
        expect(chats_controller).to include('class Llm::ChatsController')
        expect(chats_controller).to include('Llm::Chat.find')
        expect(chats_controller).to include('@llm_chat = Llm::Chat.new')
        expect(chats_controller).to include('@chat_models = RubyLLM.models.chat_models.all')
        expect(chats_controller).to include('@llm_chat = Llm::Chat.create!(model: model)')

        messages_controller = File.read('app/controllers/llm/messages_controller.rb')
        expect(messages_controller).to include('class Llm::MessagesController')
        expect(messages_controller).to include('@llm_chat = Llm::Chat.find(params[:chat_id])')
        expect(messages_controller).to include('LlmChatResponseJob.perform_later')
        expect(messages_controller).to include('format.turbo_stream')

        models_controller = File.read('app/controllers/llm/models_controller.rb')
        expect(models_controller).to include('class Llm::ModelsController')
        expect(models_controller).to include('@llm_models = RubyLLM.models.chat_models.all')
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
        success, output = run_rails_runner(test_script)
        expect(success).to be(true), output
      end
    end
  end

  describe 'with tailwind ui option' do
    let(:app_name) { 'test_app_tailwind_ui' }
    let(:app_path) { File.join(Dir.tmpdir, app_name) }

    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      template_path = File.expand_path('../../fixtures/templates', __dir__)
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_app_tailwind_ui'))
      GeneratorTestHelpers.create_test_app('test_app_tailwind_ui',
                                           template: 'default_models_tailwind_ui_template.rb',
                                           template_path: template_path)
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_app_tailwind_ui'))
    end

    it 'creates tailwind-styled views' do
      within_test_app(app_path) do
        index_view = File.read('app/views/chats/index.html.erb')
        expect(index_view).to include('bg-green-50')
        expect(index_view).to include('class="w-full"')
        expect(index_view).not_to include('<p style="color: green">')
      end
    end
  end

  describe 'with auto ui option and tailwind marker present' do
    let(:app_name) { 'test_app_auto_tailwind_ui' }
    let(:app_path) { File.join(Dir.tmpdir, app_name) }

    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      template_path = File.expand_path('../../fixtures/templates', __dir__)
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_app_auto_tailwind_ui'))
      GeneratorTestHelpers.create_test_app('test_app_auto_tailwind_ui',
                                           template: 'default_models_auto_tailwind_ui_template.rb',
                                           template_path: template_path)
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_app_auto_tailwind_ui'))
    end

    it 'selects tailwind templates automatically' do
      within_test_app(app_path) do
        index_view = File.read('app/views/chats/index.html.erb')
        expect(index_view).to include('bg-green-50')
        expect(index_view).to include('class="w-full"')
        expect(index_view).not_to include('<p style="color: green">')
      end
    end
  end
end
