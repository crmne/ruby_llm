# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/chat_ui/chat_ui_generator'
require_relative '../../support/generator_test_helpers'

RSpec.describe RubyLLM::Generators::ChatUIGenerator, :generator, type: :generator do
  include GeneratorTestHelpers

  let(:rails_root) { Rails.root }
  let(:template_path) { File.expand_path('../../fixtures/templates', __dir__) }

  def run_rails_generate(*args, chdir: app_path)
    env = {
      'BUNDLE_GEMFILE' => ENV['BUNDLE_GEMFILE'] || Bundler.default_gemfile.to_s,
      'BUNDLE_IGNORE_CONFIG' => '1',
      'OPENAI_API_KEY' => ENV.fetch('OPENAI_API_KEY', 'test')
    }
    GeneratorTestHelpers.run_command(env, ['bundle', 'exec', 'rails', 'generate', *args], chdir:)
  end

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

  def expect_generated_view_set( # rubocop:disable Metrics/AbcSize
    base_path:,
    chats_target:,
    form_partial_path:,
    model_index_collection:,
    model_partial_path:,
    approvals_base_path:,
    approvals_path_helper:
  )
    expect(File.exist?(File.join(base_path, 'chats/index.html.erb'))).to be true
    expect(File.exist?(File.join(base_path, 'chats/new.html.erb'))).to be true
    expect(File.exist?(File.join(base_path, 'chats/show.html.erb'))).to be true
    expect(File.exist?(File.join(base_path, 'chats/_chat.html.erb'))).to be true
    expect(File.exist?(File.join(base_path, 'chats/_form.html.erb'))).to be true
    expect(File.exist?(File.join(base_path, 'chats/_approvals.html.erb'))).to be true

    %w[
      messages/_assistant.html.erb
      messages/_user.html.erb
      messages/_system.html.erb
      messages/_tool.html.erb
      messages/_error.html.erb
      messages/_content.html.erb
      messages/_attachments.html.erb
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
    expect(tool_calls_partial).to include('message: message, tool_call: tool_call')
    expect(tool_calls_partial).to include('local_assigns[:message]')
    expect(tool_calls_partial).to include('id="<%= dom_id(message) %>">')
    tool_calls_default = File.read(File.join(base_path, 'messages/tool_calls/_default.html.erb'))
    expect(tool_calls_default).to include('message_tool_call_<%= tool_call.id %>')
    tool_results_default = File.read(File.join(base_path, 'messages/tool_results/_default.html.erb'))
    expect(tool_results_default).to include('tool.tool_error_message')
    expect(tool_results_default).to include('id="<%= dom_id(tool) %>"')
    expect(tool_results_default).not_to include('message_tool_result_<%= tool.id %>')
    # RubyLLM owns the models table, so the association is always :model no
    # matter what the app calls its chat class or the models UI resource.
    chat_show = File.read(File.join(base_path, 'chats/show.html.erb'))
    expect(chat_show).to include('turbo_refreshes_with method: :morph, scroll: :preserve')
    expect(tool_calls_partial).to include('message.content.present?')
    expect(chat_show).to include('.model&.label || default_model_display_name')
    chat_partial = File.read(File.join(base_path, 'chats/_chat.html.erb'))
    expect(chat_partial).to include('.model&.label || default_model_display_name')

    chat_form = File.read(File.join(base_path, 'chats/_form.html.erb'))
    expect(chat_form).to include('@chat_models.map')
    expect(chat_form).to include('[model.label, [model.provider, model.id].join(":")]')
    expect(chat_form).to include('default_model_display_name')
    create_stream = File.read(File.join(base_path, 'messages/create.turbo_stream.erb'))
    expect(create_stream).to include(%(turbo_stream.replace "#{chats_target}"))
    expect(create_stream).to include(%(render "#{form_partial_path}"))

    approvals = File.read(File.join(base_path, 'chats/_approvals.html.erb'))
    expect(approvals).to include('approvals = chat.pending_approvals')
    approval_card = File.read(File.join(approvals_base_path, '_approval.html.erb'))
    expect(approval_card).to include("#{approvals_path_helper}(chat)")
    expect(approval_card).to include('approved: true')
    expect(approval_card).to include('approved: false')
    expect(approval_card).to include('chat.tools[:run_code]&.summary(sandbox)')
    expect(approvals).to include('_tool_call_<%= approval.tool_call_id %>"] { display: none; }')
    approval_stream = File.read(File.join(approvals_base_path, 'create.turbo_stream.erb'))
    expect(approval_stream).to include('turbo_stream.replace')
    expect(approval_stream).to include('"Continuing the conversation."')
    message_form = File.read(File.join(base_path, 'messages/_form.html.erb'))
    expect(message_form).to include('chat.pending_approvals.any?')
    expect(message_form).to include('Approve or deny the requests above to continue.')
    expect(message_form.index('pending_approvals.any?')).to be < message_form.index('chat.running?')
    expect(message_form).to include('Replying…')
    expect(assistant_partial).to include('.running? %>')
    expect(assistant_partial).to include('" data-streaming" if streaming')
    expect(assistant_partial).to include('data-controller="chat-message"')
    expect(assistant_partial).to include('data-chat-message-target="source"')
    expect(assistant_partial).to include('data-chat-message-target="output"')
    expect(assistant_partial).not_to include('data-turbo-permanent')
    controller = File.read('app/javascript/controllers/chat_message_controller.js')
    expect(controller).to include('purify.sanitize(markdown.parse(this.text), sanitizeOptions)')
    expect(controller).to include('FORBID_TAGS: ["img"')
    expect(controller).to include('turbo:before-morph-element')
    expect(assistant_partial).to include('<%= streaming ? "stream" : "content" %>')
    attachments = File.read(File.join(base_path, 'messages/_attachments.html.erb'))
    expect(attachments).to include('message.attachments.attached?')
    expect(attachments).to include('number_to_human_size(attachment.byte_size)')
    %w[user assistant tool_results/_default].each do |partial|
      path = partial.include?('/') ? "messages/#{partial}.html.erb" : "messages/_#{partial}.html.erb"
      expect(File.read(File.join(base_path, path))).to include('/attachments", message: ')
    end

    models_index = File.read(File.join(base_path, 'models/index.html.erb'))
    expect(models_index).to include("@#{model_index_collection}.each do |model_info|")
    expect(models_index).to include(%(render "#{model_partial_path}",))
  end

  def expect_routes(path, namespaced: false)
    routes_content = File.read(path)
    expect(routes_content).to include('resources :chats')
    expect(routes_content).to include('resources :messages, only: [ :create ]')
    expect(routes_content).to include('resources :approvals, only: [ :create ]')
    expect(routes_content).to include('resources :models, only: [ :index, :show ]')
    expect(routes_content).to include('namespace :llm') if namespaced
  end

  def expect_broadcasting_model(path:, acts_as_message_lines:)
    message_content = File.read(path)

    acts_as_message_lines.each do |line|
      expect(message_content).to include(line)
    end
    expect(message_content).not_to include('broadcast')
    expect(message_content).not_to include('has_many_attached')
  end

  def plain_message_model = "class Message < ApplicationRecord\n  acts_as_message\nend\n"

  def expect_file_content(path, includes:, excludes: [])
    content = File.read(path)
    includes.each { |line| expect(content).to include(line) }
    excludes.each { |line| expect(content).not_to include(line) }
  end

  def expect_job_file(path:, class_name:, lookup_line:, ask_line:)
    job_content = File.read(path)
    expect(job_content).to include(class_name)
    expect(job_content).to include(lookup_line)
    expect(job_content).to include(ask_line)
    expect(job_content).not_to include('broadcast_refresh_to')
  end

  # The script sends requests through the app, and each request resets
  # the execution context a wrapping executor would still be using.
  def run_rails_runner_outside_executor(script)
    env = {
      'BUNDLE_GEMFILE' => ENV['BUNDLE_GEMFILE'] || Bundler.default_gemfile.to_s,
      'BUNDLE_IGNORE_CONFIG' => '1',
      'OPENAI_API_KEY' => ENV.fetch('OPENAI_API_KEY', 'test')
    }
    GeneratorTestHelpers.run_command(env, ['bundle', 'exec', 'rails', 'runner', '--skip-executor', script],
                                     chdir: Dir.pwd)
  end

  def give_chat_agent_an_approval_tool(agent_path)
    File.write('app/tools/send_mail_tool.rb', <<~RUBY)
      class SendMailTool < RubyLLM::Tool
        description "Sends an email"
        parameter :to, description: "The recipient"
        requires_approval

        def execute(to:) = "Sent to \#{to}"
      end
    RUBY
    agent = File.read(agent_path)
    File.write(agent_path, agent.sub(/^end\n\z/, "  tools SendMailTool\nend\n")) unless agent.include?('SendMailTool')
  end

  def broadcast_order_script(agent:, **)
    <<~RUBY
      ActiveJob::Base.queue_adapter = :test
      actions = []
      ActiveSupport::Notifications.subscribe("broadcast.action_cable") do |*, payload|
        actions << payload[:message].to_s[/action="(\\w+)"/, 1]
      end

      chat = #{agent}.create!
      created = [
        chat.add_message(role: :user, content: "Invoice Acme"),
        chat.add_message(RubyLLM::Message.new(role: :assistant, content: "Sending it.", tool_calls: {
          "call_order" => RubyLLM::ToolCall.new(id: "call_order", name: "send_mail", arguments: { "to" => "acme" })
        })),
        chat.add_message(RubyLLM::Message.new(role: :tool, tool_call_id: "call_order", content: "Sent")),
        chat.add_message(role: :assistant, content: "Done.")
      ].map(&:id)

      later = ActiveJob::Base.queue_adapter.enqueued_jobs.map { |job| job["job_class"] }.grep(/Turbo/)
      abort "broadcasts left to jobs: \#{later}" if later.any?
      refreshes = actions.count("refresh") >= created.size && (actions - %w[refresh replace]).empty?
      abort "broadcast \#{actions} for \#{created.size} messages" unless refreshes

      actions.clear
      placeholder = chat.add_message(role: :assistant, content: "")
      chunk = RubyLLM::Chunk.new(role: :assistant, content: "Hel")
      chunk.index = 0
      placeholder.broadcast_chunk(chunk)
      abort "streaming broadcast \#{actions}" unless actions.sort == %w[append append refresh]
    RUBY
  end

  def running_reply_script(agent:, controller:, assigns:, chats_path:, job:, message_key:, **)
    <<~RUBY
      ActiveJob::Base.queue_adapter = :test
      ActionController::Base.allow_forgery_protection = false
      chat = #{agent}.create!
      chat.add_message(role: :user, content: "Tell me about blocks")
      chat.add_message(role: :assistant, content: "")
      chat.update_columns(claim_token: "reply", claimed_until: 5.minutes.from_now)

      html = #{controller}.render(:show, assigns: #{assigns})
      [ "Thinking…", '<p id="new_#{message_key}"', "Replying…" ].each do |text|
        abort "running page lacks \#{text}" unless html.include?(text)
      end
      abort "running page offers the form" if html.include?('name="#{message_key}[content]"')

      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host! "localhost"
      session.post "#{chats_path}/\#{chat.id}/messages", params: { #{message_key}: { content: "Hi" } }
      abort "message answered \#{session.response.status}" unless session.response.status == 303
      jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |job| job["job_class"] == "#{job}" }
      abort "enqueued \#{jobs}" if jobs.any?

      chat.update_columns(claim_token: nil, claimed_until: nil)
      html = #{controller}.render(:show, assigns: #{assigns})
      abort "finished page still thinks" if html.include?("Thinking…")
      abort "finished page lacks the form" unless html.include?('name="#{message_key}[content]"')
    RUBY
  end

  def approval_flow_script(agent:, controller:, assigns:, chats_path:, job:, message_key:, **)
    <<~RUBY
      ActiveJob::Base.queue_adapter = :test
      ActionController::Base.allow_forgery_protection = false
      png = Rails.root.join("tmp/chart.png")
      File.binwrite(png, "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==".unpack1("m"))
      csv = Rails.root.join("tmp/report.csv")
      File.write(csv, "day,signups\nMon,12\n")

      chat = #{agent}.create!
      chat.add_message(role: :user, content: "Chart this", attachments: [ csv.to_s, png.to_s ])
      chat.add_message(RubyLLM::Message.new(role: :assistant, content: "Checking the docs first.", tool_calls: {
        "call_search" => RubyLLM::ToolCall.new(id: "call_search", name: "search_docs", arguments: { "query" => "refunds" }, remote: true),
        "call_mail" => RubyLLM::ToolCall.new(id: "call_mail", name: "send_mail", arguments: { "to" => "ops" })
      }))
      chat = #{agent}.find(chat.id)

      html = #{controller}.render(:show, assigns: #{assigns})
      [ "\#{chat.class.name.underscore.tr('/', '_')}_\#{chat.id}_approvals", "Approve search_docs?", "refunds",
        "Approve send_mail?", "<img", "chart.png", "report.csv", "disposition=attachment",
        '[id="#{message_key}_tool_call_call_search"] { display: none; }',
        '<p id="new_#{message_key}"', "Approve or deny the requests above to continue.",
        "Checking the docs first." ].each do |text|
        abort "show page lacks \#{text}" unless html.include?(text)
      end
      abort "show page offers the message form" if html.include?('name="#{message_key}[content]"')

      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host! "localhost"
      stream = { "Accept" => "text/vnd.turbo-stream.html" }
      session.post "#{chats_path}/\#{chat.id}/messages", params: { #{message_key}: { content: "Hi" } }, headers: stream
      abort "message answered \#{session.response.status}" unless session.response.status == 303
      session.post "#{chats_path}/\#{chat.id}/approvals", params: { tool_call_id: "call_search", approved: true }, headers: stream
      abort "approve answered \#{session.response.status}" unless session.response.status == 200
      abort "approve kept the card" if session.response.body.include?("Approve search_docs?")
      abort "approve continued early" if session.response.body.include?("Continuing the conversation.")
      session.post "#{chats_path}/\#{chat.id}/approvals", params: { tool_call_id: "call_mail", approved: false }, headers: stream
      abort "deny answered \#{session.response.status}" unless session.response.status == 200
      abort "deny kept the form hidden" unless session.response.body.include?("Continuing the conversation.")
      abort "deny kept a tool call hidden" if session.response.body.include?("display: none")

      decisions = RubyLLM::ActiveRecord::ToolCall.where(tool_call_id: %w[call_search call_mail]).pluck(:tool_call_id, :approval).to_h
      abort "decisions \#{decisions}" unless decisions == { "call_search" => "approved", "call_mail" => "denied" }
      jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |job| job["job_class"] == "#{job}" }
      abort "jobs \#{jobs}" unless jobs.map { |job| job["arguments"] } == [ [ chat.id ], [ chat.id ] ]
    RUBY
  end

  def model_page_script(chats_path:, **)
    <<~RUBY
      model = RubyLLM.models.find(RubyLLM.config.default_model)
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host! "localhost"
      [ {}, { provider: model.provider } ].each do |params|
        session.get "#{chats_path.sub('chats', 'models')}/\#{model.id}", params: params
        abort "model page answered \#{session.response.status} for \#{params}" unless session.response.status == 200
        abort "model page lacks \#{model.name} for \#{params}" unless session.response.body.include?(model.name)
      end
    RUBY
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
        app/controllers/approvals_controller.rb
      ],
      helper_path: 'app/helpers/messages_helper.rb',
      view_example: 'creates view files with default paths',
      view_options: {
        base_path: 'app/views',
        chats_target: 'new_message',
        form_partial_path: 'messages/form',
        model_index_collection: 'models',
        model_partial_path: 'models/model',
        approvals_base_path: 'app/views/approvals',
        approvals_path_helper: 'chat_approvals_path'
      },
      job_file_example: 'creates job file with default name',
      job_file_path: 'app/jobs/chat_response_job.rb',
      routes_example: 'adds routes for default controllers',
      namespaced_routes: false,
      broadcasting_example: 'leaves broadcasting to acts_as_message',
      broadcasting_options: {
        path: 'app/models/message.rb',
        acts_as_message_lines: ['acts_as_message']
      },
      controllers_example: 'controllers reference correct model classes',
      chats_controller_path: 'app/controllers/chats_controller.rb',
      chats_controller_expectations: [
        'class ChatsController',
        '@chat = ChatAgent.find(params[:id])',
        '@chat = Chat.new',
        '@chat_models = available_chat_models',
        'prompt = params.dig(:chat, :prompt)',
        'if prompt.present?',
        'ChatResponseJob.set(wait: 1.second).perform_later(@chat.id, prompt)',
        'provider, model = params.dig(:chat, :model).to_s.split(":", 2)',
        '@chat = ChatAgent.create!(**{ model: model.presence, provider: provider.presence }.compact)',
        '@chat.errors.add(:prompt, "can\'t be blank")',
        'render :new, status:'
      ],
      messages_controller_path: 'app/controllers/messages_controller.rb',
      messages_controller_expectations: [
        'class MessagesController',
        '@chat = ChatAgent.find(params[:chat_id])',
        'content = params.dig(:message, :content)',
        'if @chat.pending_approvals.any?',
        'elsif @chat.running?',
        'if content.present?',
        'ChatResponseJob.perform_later',
        'format.turbo_stream',
        '@message = @chat.messages.build',
        '@message.errors.add(:content, "can\'t be blank")',
        'render "chats/show", status:'
      ],
      approvals_controller_path: 'app/controllers/approvals_controller.rb',
      approvals_controller_expectations: [
        'class ApprovalsController',
        '@chat = ChatAgent.find(params[:chat_id])',
        '@chat.approve(params[:tool_call_id])',
        '@chat.deny(params[:tool_call_id])',
        'ChatResponseJob.perform_later(@chat.id)',
        'rescue_from RubyLLM::ToolCallRunningError'
      ],
      approval_flow: {
        agent: 'ChatAgent', agent_path: 'app/agents/chat_agent.rb', controller: 'ChatsController',
        assigns: '{ chat: chat, message: Message.new }', chats_path: '/chats',
        job: 'ChatResponseJob', message_key: 'message'
      },
      models_controller_path: 'app/controllers/models_controller.rb',
      models_controller_expectations: [
        'class ModelsController',
        '@models = available_chat_models'
      ],
      job_example: 'job references correct model classes',
      job_options: {
        path: 'app/jobs/chat_response_job.rb',
        class_name: 'class ChatResponseJob',
        lookup_line: 'chat = ChatAgent.find(chat_id)',
        ask_line: 'content ? chat.ask(content, &:broadcast) : chat.complete(&:broadcast)'
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
        app/controllers/llm/approvals_controller.rb
      ],
      helper_path: 'app/helpers/llm/messages_helper.rb',
      view_example: 'creates view files with namespaced paths',
      view_options: {
        base_path: 'app/views/llm',
        chats_target: 'new_llm_message',
        form_partial_path: 'llm/messages/form',
        model_index_collection: 'llm_models',
        model_partial_path: 'llm/models/model',
        approvals_base_path: 'app/views/llm/approvals',
        approvals_path_helper: 'llm_chat_approvals_path'
      },
      job_file_example: 'creates job file with namespaced name',
      job_file_path: 'app/jobs/llm_chat_response_job.rb',
      routes_example: 'adds routes for namespaced controllers',
      namespaced_routes: true,
      broadcasting_example: 'leaves broadcasting to acts_as_message in the namespaced model',
      broadcasting_options: {
        path: 'app/models/llm/message.rb',
        acts_as_message_lines: [
          "acts_as_message chat: :llm_chat, chat_class: 'Llm::Chat'"
        ]
      },
      controllers_example: 'controllers reference correct namespaced model classes',
      chats_controller_path: 'app/controllers/llm/chats_controller.rb',
      chats_controller_expectations: [
        'class Llm::ChatsController',
        '@llm_chat = Llm::ChatAgent.find(params[:id])',
        '@llm_chat = Llm::Chat.new',
        '@chat_models = available_chat_models',
        'prompt = params.dig(:llm_chat, :prompt)',
        'if prompt.present?',
        'provider, model = params.dig(:llm_chat, :model).to_s.split(":", 2)',
        '@llm_chat = Llm::ChatAgent.create!(**{ model: model.presence, provider: provider.presence }.compact)',
        '@llm_chat.errors.add(:prompt, "can\'t be blank")',
        'render :new, status:'
      ],
      messages_controller_path: 'app/controllers/llm/messages_controller.rb',
      messages_controller_expectations: [
        'class Llm::MessagesController',
        '@llm_chat = Llm::ChatAgent.find(params[:chat_id])',
        'content = params.dig(:llm_message, :content)',
        'if @llm_chat.pending_approvals.any?',
        'elsif @llm_chat.running?',
        'if content.present?',
        'LlmChatResponseJob.perform_later',
        'format.turbo_stream',
        '@llm_message = @llm_chat.llm_messages.build',
        '@llm_message.errors.add(:content, "can\'t be blank")',
        'render "llm/chats/show", status:'
      ],
      approvals_controller_path: 'app/controllers/llm/approvals_controller.rb',
      approvals_controller_expectations: [
        'class Llm::ApprovalsController',
        '@llm_chat = Llm::ChatAgent.find(params[:chat_id])',
        '@llm_chat.approve(params[:tool_call_id])',
        '@llm_chat.deny(params[:tool_call_id])',
        'LlmChatResponseJob.perform_later(@llm_chat.id)',
        'rescue_from RubyLLM::ToolCallRunningError'
      ],
      approval_flow: {
        agent: 'Llm::ChatAgent', agent_path: 'app/agents/llm/chat_agent.rb', controller: 'Llm::ChatsController',
        assigns: '{ llm_chat: chat, llm_message: Llm::Message.new }', chats_path: '/llm/chats',
        job: 'LlmChatResponseJob', message_key: 'llm_message'
      },
      models_controller_path: 'app/controllers/llm/models_controller.rb',
      models_controller_expectations: [
        'class Llm::ModelsController',
        '@llm_models = available_chat_models'
      ],
      job_example: 'job references correct namespaced model classes',
      job_options: {
        path: 'app/jobs/llm_chat_response_job.rb',
        class_name: 'class LlmChatResponseJob',
        lookup_line: 'llm_chat = Llm::ChatAgent.find(llm_chat_id)',
        ask_line: 'content ? llm_chat.ask(content, &:broadcast) : llm_chat.complete(&:broadcast)'
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
        expect(show_view).not_to include('llm/chat:')
        expect(show_view).to include('render "llm/chats/approvals", chat: @llm_chat')

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
        it 'adds yield :head to a layout without it, once' do
          Dir.mktmpdir do |destination|
            FileUtils.cp_r("#{app_path}/.", destination)
            within_test_app(destination) do
              layout = 'app/views/layouts/application.html.erb'
              File.write(layout, File.read(layout).gsub(/^.*yield :head.*\n/, ''))

              2.times do
                output, status = run_rails_generate('ruby_llm:chat_ui', '--skip', chdir: destination)
                expect(status.success?).to be(true), output
              end
              expect(File.read(layout).scan('<%= yield :head %>').size).to eq(1)
              expect(File.read(layout)).to match(%r{<%= yield :head %>\n\s*</head>})
            end
          end
        end

        it 'pins its JavaScript dependencies with importmap, once' do
          Dir.mktmpdir do |destination|
            FileUtils.cp_r("#{app_path}/.", destination)
            within_test_app(destination) do
              File.write('config/importmap.rb', %(pin "application"\n))
              File.write('bin/importmap', <<~SH)
                #!/bin/sh
                echo "$@" >> tmp/importmap_calls
                echo 'pin "marked" # @18.0.14' >> config/importmap.rb
                echo 'pin "dompurify" # @3.4.16' >> config/importmap.rb
              SH
              FileUtils.chmod('+x', 'bin/importmap')

              2.times do
                output, status = run_rails_generate('ruby_llm:chat_ui', '--skip', chdir: destination)
                expect(status.success?).to be(true), output
              end
              expect(File.read('tmp/importmap_calls')).to eq("pin marked@18.0.14 dompurify@3.4.16\n")
            end
          end
        end

        it 'leaves the message model to acts_as_message when run again, with or without --force' do
          Dir.mktmpdir do |destination|
            FileUtils.cp_r("#{app_path}/.", destination)
            within_test_app(destination) do
              [%w[--skip], %w[--force]].each do |flags|
                output, status = run_rails_generate('ruby_llm:chat_ui', *flags, chdir: destination)
                expect(status.success?).to be(true), output
              end

              expect(File.read('app/models/message.rb')).to eq(plain_message_model)
              initializer = File.read('config/initializers/ruby_llm.rb')
              expect(initializer.scan('config.broadcast_messages = true').size).to eq(1)
            end
          end
        end

        {
          '2.1' => <<~'RUBY',
            class Message < ApplicationRecord
              acts_as_message
              has_many_attached :attachments

              broadcasts_to ->(message) { "chat_#{message.chat_id}" }, inserts_by: :append

              def broadcast_append_chunk(content)
                broadcast_append_to "chat_#{chat_id}",
                  target: "message_#{id}_content",
                  content: ERB::Util.html_escape(content.to_s)
              end
            end
          RUBY
          'the numbered-chunk chat UI' => <<~'RUBY'
            class Message < ApplicationRecord
              acts_as_message
              has_many_attached :attachments

              after_create_commit -> { broadcast_append_to "chat_#{chat_id}" if role.to_s == "assistant" && content.blank? }
              after_update_commit -> { broadcast_replace_to "chat_#{chat_id}" }
              after_destroy_commit -> { broadcast_remove_to "chat_#{chat_id}" }
              after_commit -> { broadcast_refresh_to "chat_#{chat_id}" }

              def broadcast_append_chunk(content, sequence)
                broadcast_append_to "chat_#{chat_id}",
                  target: "message_#{id}_stream",
                  content: %(<span data-seq="#{sequence}">#{ERB::Util.html_escape(content)}</span>)
              end
            end
          RUBY
        }.each do |version, model|
          it "removes the broadcasting #{version} wrote into the message model" do
            Dir.mktmpdir do |destination|
              FileUtils.cp_r("#{app_path}/.", destination)
              within_test_app(destination) do
                File.write('app/models/message.rb', model)

                output, status = run_rails_generate('ruby_llm:chat_ui', '--skip', chdir: destination)
                expect(status.success?).to be(true), output
                expect(File.read('app/models/message.rb')).to eq(plain_message_model)
                expect(output).not_to include('broadcasts with Turbo itself')
              end
            end
          end
        end

        it 'leaves broadcasting code it did not write alone and explains what to change' do
          Dir.mktmpdir do |destination|
            FileUtils.cp_r("#{app_path}/.", destination)
            within_test_app(destination) do
              custom = <<~RUBY
                class Message < ApplicationRecord
                  acts_as_message
                  broadcasts_to ->(message) { [message.chat, :messages] }
                end
              RUBY
              File.write('app/models/message.rb', custom)

              output, status = run_rails_generate('ruby_llm:chat_ui', '--skip', chdir: destination)
              expect(status.success?).to be(true), output
              expect(File.read('app/models/message.rb')).to eq(custom)
              expect(output).to include('Message broadcasts with Turbo itself')
              expect(output).to include("the chat UI turns on RubyLLM's broadcasting")
              expect(output).to include('acts_as_message broadcasts: false')
            end
          end
        end

        it 'explains that replies stay plain text in an app without JavaScript' do
          Dir.mktmpdir do |destination|
            FileUtils.cp_r("#{app_path}/.", destination)
            within_test_app(destination) do
              output, status = run_rails_generate('ruby_llm:chat_ui', '--skip', chdir: destination)
              expect(status.success?).to be(true), output
              expect(output).to include('Your app has no JavaScript setup, so replies show as plain text')
            end
          end
        end

        it 'prints the packages to install for a jsbundling app' do
          Dir.mktmpdir do |destination|
            FileUtils.cp_r("#{app_path}/.", destination)
            within_test_app(destination) do
              File.write('package.json', '{}')
              output, status = run_rails_generate('ruby_llm:chat_ui', '--skip', chdir: destination)
              expect(status.success?).to be(true), output
              expect(output).to include('yarn add marked@18.0.14 dompurify@3.4.16')
              expect(output).to include('bin/rails stimulus:manifest:update')
              expect(output).to include('bin/rails stimulus:install')
            end
          end
        end

        it 'gives the chat agent its chat model without an ApplicationAgent' do
          Dir.mktmpdir do |destination|
            FileUtils.cp_r("#{app_path}/.", destination)
            within_test_app(destination) do
              FileUtils.rm('app/agents/application_agent.rb')

              output, status = run_rails_generate('ruby_llm:chat_ui', '--force', chdir: destination)
              expect(status.success?).to be(true), output
              expect(File.read('app/agents/chat_agent.rb'))
                .to eq("class ChatAgent < RubyLLM::Agent\n  chat_model Chat\nend\n")
            end
          end
        end

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

      if description == 'with namespaced model names'
        it 'honors mappings that follow UI options' do
          Dir.mktmpdir do |destination|
            FileUtils.cp_r("#{app_path}/.", destination)
            within_test_app(destination) do
              FileUtils.rm('app/controllers/llm/chats_controller.rb')

              output, status = run_rails_generate(
                'ruby_llm:chat_ui', '--force', '--ui', 'scaffold',
                'chat:Llm::Chat', 'message:Llm::Message', chdir: destination
              )
              expect(status.success?).to be(true), output

              controller = File.read('app/controllers/llm/chats_controller.rb')
              expect(controller).to include('class Llm::ChatsController')
              expect(controller).to include('Llm::ChatAgent.find')
              expect_chat_script_to_succeed('Rails.application.eager_load!')
            end
          end
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

          chat_agent = File.read(config[:approval_flow][:agent_path])
          expect(chat_agent).to start_with("class #{config[:approval_flow][:agent]} < ApplicationAgent\n")
          expect(chat_agent).not_to include('chat_model')

          approvals_controller = File.read(config[:approvals_controller_path])
          config[:approvals_controller_expectations].each do |line|
            expect(approvals_controller).to include(line)
          end

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
        # rubocop:disable-next RSpec/NoExpectationExample
        it config[:extra_view_example] do
          within_test_app(app_path) do
            instance_exec(&config[:extra_view_assertions])
          end
        end
      end

      it 'refreshes for message changes and appends streamed chunks' do
        within_test_app(app_path) do
          give_chat_agent_an_approval_tool(config[:approval_flow][:agent_path])
          success, output = run_rails_runner(broadcast_order_script(**config[:approval_flow]))
          expect(success).to be(true), output
        end
      end

      it 'shows Thinking and Replying while a reply runs, and refuses messages' do
        within_test_app(app_path) do
          output, status = run_rails_runner_outside_executor(running_reply_script(**config[:approval_flow]))
          expect(status.success?).to be(true), output
        end
      end

      it 'renders approvals and attachments and records decisions' do
        within_test_app(app_path) do
          give_chat_agent_an_approval_tool(config[:approval_flow][:agent_path])
          output, status = run_rails_runner_outside_executor(approval_flow_script(**config[:approval_flow]))
          expect(status.success?).to be(true), output
        end
      end

      it 'shows a model with or without its provider' do
        within_test_app(app_path) do
          output, status = run_rails_runner_outside_executor(model_page_script(**config[:approval_flow]))
          expect(status.success?).to be(true), output
        end
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
