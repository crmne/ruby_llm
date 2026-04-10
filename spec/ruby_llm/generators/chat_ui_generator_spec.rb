# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/chat_ui/chat_ui_generator'
require_relative '../../support/generator_test_helpers'

RSpec.describe RubyLLM::Generators::ChatUIGenerator, :generator, type: :generator do
  include GeneratorTestHelpers

  let(:rails_root) { Rails.root }
  let(:template_path) { File.expand_path('../../fixtures/templates', __dir__) }

  def expect_messages_helper_content(path)
    messages_helper = File.read(path)
    expect(messages_helper).to include('def default_model_display_name')
    expect(messages_helper).not_to include('def llm_model_label(model)')
    expect(messages_helper).to include('RubyLLM.models.find(RubyLLM.config.default_model).label')
    expect(messages_helper).to include('def tool_result_partial(message)')
    expect(messages_helper).to include('def tool_call_partial(tool_call)')
    expect(messages_helper).not_to include('def model_display_name(model)')
    expect(messages_helper).not_to include('def provider_display_name(model_or_provider)')
    expect(messages_helper).not_to include('def parse_tool_payload(content)')
    expect(messages_helper).not_to include('def llm_model_info(model)')
  end

  def expect_generated_view_set(
    base_path:,
    chats_target:,
    form_partial_path:,
    model_index_collection:,
    model_partial_path:
  )
    expect(File.exist?(File.join(base_path, 'chats/index.html.erb'))).to be true
    expect(File.exist?(File.join(base_path, 'chats/new.html.erb'))).to be true
    expect(File.exist?(File.join(base_path, 'chats/show.html.erb'))).to be true
    expect(File.exist?(File.join(base_path, 'chats/_chat.html.erb'))).to be true
    expect(File.exist?(File.join(base_path, 'chats/_form.html.erb'))).to be true

    %w[
      messages/_assistant.html.erb
      messages/_user.html.erb
      messages/_system.html.erb
      messages/_tool.html.erb
      messages/_error.html.erb
      messages/_content.html.erb
      messages/_tool_calls.html.erb
      messages/tool_calls/_default.html.erb
      messages/tool_results/_default.html.erb
      messages/create.turbo_stream.erb
      messages/_form.html.erb
      models/index.html.erb
      models/show.html.erb
      models/_model.html.erb
    ].each do |relative_path|
      expect(File.exist?(File.join(base_path, relative_path))).to be true
    end

    user_partial = File.read(File.join(base_path, 'messages/_user.html.erb'))
    expect(user_partial).to include('user.content')
    expect(user_partial).to include('local_assigns[:message]')
    assistant_partial = File.read(File.join(base_path, 'messages/_assistant.html.erb'))
    expect(assistant_partial).to include('assistant.content')
    expect(assistant_partial).to include('local_assigns[:message]')
    system_partial = File.read(File.join(base_path, 'messages/_system.html.erb'))
    expect(system_partial).to include('system.content')
    expect(system_partial).to include('local_assigns[:message]')
    tool_partial = File.read(File.join(base_path, 'messages/_tool.html.erb'))
    expect(tool_partial).to include('render tool_result_partial(tool), tool: tool')
    tool_calls_partial = File.read(File.join(base_path, 'messages/_tool_calls.html.erb'))
    expect(tool_calls_partial).to include('tool_calls: tool_calls, tool_call: tool_call')
    expect(tool_calls_partial).to include('local_assigns[:message]')
    tool_results_default = File.read(File.join(base_path, 'messages/tool_results/_default.html.erb'))
    expect(tool_results_default).to include('tool.tool_error_message')
    chat_form = File.read(File.join(base_path, 'chats/_form.html.erb'))
    expect(chat_form).to include('@chat_models.map')
    expect(chat_form).to include('[model.label, model.id]')
    expect(chat_form).to include('default_model_display_name')
    create_stream = File.read(File.join(base_path, 'messages/create.turbo_stream.erb'))
    expect(create_stream).to include(%(turbo_stream.replace "#{chats_target}"))
    expect(create_stream).to include(%(render "#{form_partial_path}"))

    models_index = File.read(File.join(base_path, 'models/index.html.erb'))
    expect(models_index).to include("@#{model_index_collection}.each do |model_info|")
    expect(models_index).to include(%(render "#{model_partial_path}",))
  end

  def expect_routes(path, namespaced: false)
    routes_content = File.read(path)
    expect(routes_content).to include('resources :chats')
    expect(routes_content).to include('resources :messages, only: [ :create ]')
    expect(routes_content).to include('resources :models, only: [ :index, :show ]')
    expect(routes_content).to include('namespace :llm') if namespaced
  end

  def expect_broadcasting_model(
    path:,
    acts_as_message_lines:,
    broadcasts_to_line:,
    broadcast_target_line:,
    content_target_line:
  )
    message_content = File.read(path)

    acts_as_message_lines.each do |line|
      expect(message_content).to include(line)
    end

    expect(message_content).to include(broadcasts_to_line)
    expect(message_content).to include('inserts_by: :append')
    expect(message_content).to include('def broadcast_append_chunk(content)')
    expect(message_content).to include(broadcast_target_line)
    expect(message_content).to include(content_target_line)
    expect(message_content).to include('content: ERB::Util.html_escape(content.to_s)')
  end

  def expect_file_content(path, includes:, excludes: [])
    content = File.read(path)
    includes.each { |line| expect(content).to include(line) }
    excludes.each { |line| expect(content).not_to include(line) }
  end

  def expect_job_file(path:, class_name:, lookup_line:, ask_line:, last_message_line:)
    job_content = File.read(path)
    expect(job_content).to include(class_name)
    expect(job_content).to include(lookup_line)
    expect(job_content).to include(ask_line)
    expect(job_content).to include(last_message_line)
  end

  def expect_chat_script_to_succeed(script)
    success, output = run_rails_runner(script)
    expect(success).to be(true), output
  end

  {
    'with default model names' => {
      app_name: 'test_app_default',
      template_name: 'default_models_template.rb',
      controller_example: 'creates controller files with default names',
      controller_paths: %w[
        app/controllers/chats_controller.rb
        app/controllers/messages_controller.rb
        app/controllers/models_controller.rb
      ],
      helper_path: 'app/helpers/messages_helper.rb',
      view_example: 'creates view files with default paths',
      view_options: {
        base_path: 'app/views',
        chats_target: 'new_message',
        form_partial_path: 'messages/form',
        model_index_collection: 'models',
        model_partial_path: 'models/model'
      },
      job_file_example: 'creates job file with default name',
      job_file_path: 'app/jobs/chat_response_job.rb',
      routes_example: 'adds routes for default controllers',
      namespaced_routes: false,
      broadcasting_example: 'adds broadcasting to message model',
      broadcasting_options: {
        path: 'app/models/message.rb',
        acts_as_message_lines: ['acts_as_message'],
        broadcasts_to_line: "broadcasts_to ->(message) { \"chat_\#{message.chat_id}\" }",
        broadcast_target_line: "broadcast_append_to \"chat_\#{chat_id}\"",
        content_target_line: "target: \"message_\#{id}_content\""
      },
      controllers_example: 'controllers reference correct model classes',
      chats_controller_path: 'app/controllers/chats_controller.rb',
      chats_controller_expectations: [
        'class ChatsController',
        'Chat.find',
        '@chat = Chat.new',
        '@chat_models = available_chat_models',
        'prompt = params.dig(:chat, :prompt)',
        'if prompt.present?',
        '@chat = Chat.create!(model: params.dig(:chat, :model).presence)'
      ],
      messages_controller_path: 'app/controllers/messages_controller.rb',
      messages_controller_expectations: [
        'class MessagesController',
        '@chat = Chat.find(params[:chat_id])',
        'content = params.dig(:message, :content)',
        'if content.present?',
        'ChatResponseJob.perform_later',
        'format.turbo_stream'
      ],
      models_controller_path: 'app/controllers/models_controller.rb',
      models_controller_expectations: [
        'class ModelsController',
        '@models = available_chat_models'
      ],
      job_example: 'job references correct model classes',
      job_options: {
        path: 'app/jobs/chat_response_job.rb',
        class_name: 'class ChatResponseJob',
        lookup_line: 'chat = Chat.find(chat_id)',
        ask_line: 'chat.ask(content)',
        last_message_line: 'message = chat.messages.last'
      },
      functionality_example: 'chat functionality works correctly',
      functionality_script: <<~RUBY
        ActiveJob::Base.queue_adapter = :inline
        chat = Chat.create!
        message = chat.messages.create!(role: :user, content: 'Test')
        exit(message.chat_id == chat.id ? 0 : 1)
      RUBY
    },
    'with namespaced model names' => {
      app_name: 'test_app_namespaced',
      template_name: 'namespaced_models_template.rb',
      controller_example: 'creates controller files with namespaced paths',
      controller_paths: %w[
        app/controllers/llm/chats_controller.rb
        app/controllers/llm/messages_controller.rb
        app/controllers/llm/models_controller.rb
      ],
      helper_path: 'app/helpers/llm/messages_helper.rb',
      view_example: 'creates view files with namespaced paths',
      view_options: {
        base_path: 'app/views/llm',
        chats_target: 'new_llm_message',
        form_partial_path: 'llm/messages/form',
        model_index_collection: 'llm_models',
        model_partial_path: 'llm/models/model'
      },
      job_file_example: 'creates job file with namespaced name',
      job_file_path: 'app/jobs/llm_chat_response_job.rb',
      routes_example: 'adds routes for namespaced controllers',
      namespaced_routes: true,
      broadcasting_example: 'adds broadcasting to namespaced message model',
      broadcasting_options: {
        path: 'app/models/llm/message.rb',
        acts_as_message_lines: [
          "acts_as_message chat: :llm_chat, chat_class: 'Llm::Chat'",
          "tool_calls: :llm_tool_calls, tool_call_class: 'Llm::ToolCall'",
          "model: :llm_model, model_class: 'Llm::Model'"
        ],
        broadcasts_to_line: "broadcasts_to ->(llm_message) { \"llm_chat_\#{llm_message.llm_chat_id}\" }",
        broadcast_target_line: "broadcast_append_to \"llm_chat_\#{llm_chat_id}\"",
        content_target_line: "target: \"llm_message_\#{id}_content\""
      },
      controllers_example: 'controllers reference correct namespaced model classes',
      chats_controller_path: 'app/controllers/llm/chats_controller.rb',
      chats_controller_expectations: [
        'class Llm::ChatsController',
        'Llm::Chat.find',
        '@llm_chat = Llm::Chat.new',
        '@chat_models = available_chat_models',
        'prompt = params.dig(:llm_chat, :prompt)',
        'if prompt.present?',
        '@llm_chat = Llm::Chat.create!(model:',
        'params.dig(:llm_chat, :model).presence)'
      ],
      messages_controller_path: 'app/controllers/llm/messages_controller.rb',
      messages_controller_expectations: [
        'class Llm::MessagesController',
        '@llm_chat = Llm::Chat.find(params[:chat_id])',
        'content = params.dig(:llm_message, :content)',
        'if content.present?',
        'LlmChatResponseJob.perform_later',
        'format.turbo_stream'
      ],
      models_controller_path: 'app/controllers/llm/models_controller.rb',
      models_controller_expectations: [
        'class Llm::ModelsController',
        '@llm_models = available_chat_models'
      ],
      job_example: 'job references correct namespaced model classes',
      job_options: {
        path: 'app/jobs/llm_chat_response_job.rb',
        class_name: 'class LlmChatResponseJob',
        lookup_line: 'llm_chat = Llm::Chat.find(llm_chat_id)',
        ask_line: 'llm_chat.ask(content)',
        last_message_line: 'llm_message = llm_chat.llm_messages.last'
      },
      extra_view_example: 'views use correct partial paths',
      extra_view_assertions: lambda do
        show_view = File.read('app/views/llm/chats/show.html.erb')
        expect(show_view).to include('render')
        expect(show_view).to include('render "llm/messages/form"')
        expect(show_view).to include('llm_message: @llm_message')
        expect(show_view).to include('llm_chat: @llm_chat')
        expect(show_view).not_to include('llm/message:')
        expect(show_view).not_to include('@llm/message')
        expect(show_view).not_to include('llm/chat')

        index_view = File.read('app/views/llm/chats/index.html.erb')
        expect(index_view).to include('render llm_chat')
        expect(index_view).to include('@llm_chats.each do |llm_chat|')
      end,
      functionality_example: 'namespaced chat functionality works correctly',
      functionality_script: <<~RUBY
        ActiveJob::Base.queue_adapter = :inline
        chat = Llm::Chat.create!
        message = chat.llm_messages.create!(role: :user, content: 'Test')
        exit(message.llm_chat_id == chat.id ? 0 : 1)
      RUBY
    }
  }.each do |description, config|
    describe description do
      let(:app_path) { File.join(Dir.tmpdir, config[:app_name]) }

      before(:all) do # rubocop:disable RSpec/BeforeAfterAll
        GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, config[:app_name]))
        GeneratorTestHelpers.create_test_app(
          config[:app_name],
          template: config[:template_name],
          template_path: File.expand_path('../../fixtures/templates', __dir__)
        )
      end

      after(:all) do # rubocop:disable RSpec/BeforeAfterAll
        GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, config[:app_name]))
      end

      it config[:controller_example] do
        within_test_app(app_path) do
          config[:controller_paths].each do |path|
            expect(File.exist?(path)).to be true
          end

          expect(File.exist?(config[:helper_path])).to be true
          expect_messages_helper_content(config[:helper_path])
        end
      end

      it config[:view_example] do
        within_test_app(app_path) do
          expect_generated_view_set(**config[:view_options])
        end
      end

      if description == 'with default model names'
        it 'uses scaffold-style inline styles by default' do
          within_test_app(app_path) do
            index_view = File.read('app/views/chats/index.html.erb')
            expect(index_view).to include('<p style="color: green">')
            expect(index_view).not_to include('text-green-700')
          end
        end
      end

      it config[:job_file_example] do
        within_test_app(app_path) do
          expect(File.exist?(config[:job_file_path])).to be true
        end
      end

      it config[:routes_example] do
        within_test_app(app_path) do
          expect_routes('config/routes.rb', namespaced: config[:namespaced_routes])
        end
      end

      it config[:broadcasting_example] do
        within_test_app(app_path) do
          expect_broadcasting_model(**config[:broadcasting_options])
        end
      end

      it config[:controllers_example] do
        within_test_app(app_path) do
          chats_controller = File.read(config[:chats_controller_path])
          config[:chats_controller_expectations].each do |line|
            expect(chats_controller).to include(line)
          end
          expect(chats_controller).not_to include('def model')
          expect(chats_controller).not_to include('def prompt')

          messages_controller = File.read(config[:messages_controller_path])
          config[:messages_controller_expectations].each do |line|
            expect(messages_controller).to include(line)
          end
          expect(messages_controller).not_to include('def content')

          models_controller = File.read(config[:models_controller_path])
          config[:models_controller_expectations].each do |line|
            expect(models_controller).to include(line)
          end

          expect_file_content(
            'app/controllers/application_controller.rb',
            includes: [
              'def available_chat_models',
              'sort_by { |model| [ model.provider.to_s, model.name.to_s ] }'
            ]
          )
        end
      end

      it config[:job_example] do
        within_test_app(app_path) do
          expect_job_file(**config[:job_options])
        end
      end

      if config[:extra_view_example]
        # rubocop:disable RSpec/NoExpectationExample
        it config[:extra_view_example] do
          within_test_app(app_path) do
            instance_exec(&config[:extra_view_assertions])
          end
        end
        # rubocop:enable RSpec/NoExpectationExample
      end

      it config[:functionality_example] do
        within_test_app(app_path) do
          expect_chat_script_to_succeed(config[:functionality_script])
        end
      end
    end
  end

  {
    'with tailwind ui option' => [
      'test_app_tailwind_ui',
      'default_models_tailwind_ui_template.rb',
      'creates tailwind-styled views'
    ],
    'with auto ui option and tailwind marker present' => [
      'test_app_auto_tailwind_ui',
      'default_models_auto_tailwind_ui_template.rb',
      'selects tailwind templates automatically'
    ]
  }.each do |description, (app_name, template_name, example_name)|
    describe description do
      let(:app_path) { File.join(Dir.tmpdir, app_name) }

      before(:all) do # rubocop:disable RSpec/BeforeAfterAll
        GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, app_name))
        GeneratorTestHelpers.create_test_app(
          app_name,
          template: template_name,
          template_path: File.expand_path('../../fixtures/templates', __dir__)
        )
      end

      after(:all) do # rubocop:disable RSpec/BeforeAfterAll
        GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, app_name))
      end

      it example_name do
        within_test_app(app_path) do
          expect_file_content(
            'app/views/chats/index.html.erb',
            includes: ['bg-green-50', 'class="w-full"'],
            excludes: ['<p style="color: green">']
          )
        end
      end
    end
  end
end
