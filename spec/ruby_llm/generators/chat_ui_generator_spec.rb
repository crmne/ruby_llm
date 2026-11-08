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
    run_rails('generate', *args, chdir:)
  end

  def run_rails(*args, chdir: Dir.pwd, env: {})
    env = {
      'BUNDLE_GEMFILE' => ENV['BUNDLE_GEMFILE'] || Bundler.default_gemfile.to_s,
      'BUNDLE_IGNORE_CONFIG' => '1',
      'OPENAI_API_KEY' => ENV.fetch('OPENAI_API_KEY', 'test'),
      **env
    }
    GeneratorTestHelpers.run_command(env, ['bundle', 'exec', 'rails', *args], chdir:)
  end

  def expect_generated_view_set( # rubocop:disable Metrics/AbcSize
    base_path:,
    chats_target:,
    chat_views_path:,
    chat:,
    form_partial_path:,
    model_index_collection:,
    model_partial_path:,
    questions_base_path:,
    answers_base_path:,
    answers_path_helper:
  )
    %w[index new show _chat _form _model_select _questions _files].each do |view|
      expect(File.exist?(File.join(base_path, "chats/#{view}.html.erb"))).to be true
    end

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
      messages/_queued_message.html.erb
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
    # The shipped Stimulus controller refreshes the page when this stream connects.
    expect(chat_show).to match(/turbo_stream_from @\w+, data: \{ chat_stream: true \} %>/)
    expect(tool_calls_partial).to include('message.content.present?')
    expect(chat_show).to include('.model&.label || default_model_display_name')
    expect(chat_show).to include('button_to "Stop", cancel_')
    expect(chat_show).to include('.cost.total')
    expect(File.read(File.join(base_path, 'messages/_assistant.html.erb'))).to include('assistant.cost.total')
    chat_partial = File.read(File.join(base_path, 'chats/_chat.html.erb'))
    expect(chat_partial).to include('.model&.label || default_model_display_name')

    model_select = File.read(File.join(base_path, 'chats/_model_select.html.erb'))
    expect(model_select).to include('@chat_models.map', 'default_model_display_name', 'form.select :model,')
    expect(model_select).to include('[model.label, [model.provider, model.id].join(":")]')
    chat_form = File.read(File.join(base_path, 'chats/_form.html.erb'))
    expect(chat_form).to include(%(render "#{chat_views_path}/model_select", form: form, selected: @selected_model))
    create_stream = File.read(File.join(base_path, 'messages/create.turbo_stream.erb'))
    expect(create_stream).to include(%(turbo_stream.replace "#{chats_target}"))
    expect(create_stream).to include(%(render "#{form_partial_path}"))

    expect_question_views(base_path, questions_base_path, answers_base_path, answers_path_helper)
    message_form = File.read(File.join(base_path, 'messages/_form.html.erb'))
    expect(message_form).to include('chat.pending_questions.any?', 'Answer the questions above to continue.')
    expect(message_form).to include(%(render "#{chat_views_path}/model_select", form: form, ) +
                                    %(selected: [ #{chat}.provider, #{chat}.model_id ].compact.join(":")))
    expect(message_form).not_to include('Replying…')
    expect_draft_form(message_form)
    expect_queued_message_views(base_path, answers_path_helper.sub('answers', 'queued_message'))
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

  def expect_question_views(base_path, questions_base_path, answers_base_path, answers_path_helper)
    questions = File.read(File.join(base_path, 'chats/_questions.html.erb'))
    expect(questions).to include('questions = chat.pending_questions')
    expect(questions).to include('_tool_call_<%= question.tool_call.id %>"] { display: none; }')
    question_card = File.read(File.join(questions_base_path, '_question.html.erb'))
    expect(question_card).to include("#{answers_path_helper}(chat)")
    expect(question_card).to include('params: { question_id: question.id }')
    expect(question_card).to include('params: { question_id: question.id, decline: true }')
    expect(question_card).to include('params: { question_id: question.id, answer: value }')
    expect(question_card).to include('{ "Yes" => true, "No" => false } if single&.type == "boolean"')
    expect(question_card).to include('link_to question.url, question.url, target: "_blank", rel: "noopener noreferrer"')
    expect(question_card).to include('form.button "Decline", name: :decline, value: true, formnovalidate: true')
    expect(question_card).to include('chat.tools[:run_code]&.summary(sandbox)')
    answer_stream = File.read(File.join(answers_base_path, 'create.turbo_stream.erb'))
    expect(answer_stream).to include('turbo_stream.replace')
    expect(answer_stream).to include('"Continuing the conversation."')
  end

  def expect_draft_form(message_form)
    expect(message_form).to include('", data: { chat_draft: true }')
    expect(message_form.scan('chat_draft').size).to eq(1)
    expect(File.read('app/javascript/controllers/chat_message_controller.js'))
      .to include('element.form?.hasAttribute("data-chat-draft")', 'option.defaultSelected')
  end

  def expect_queued_message_views(base_path, path_helper)
    queued_message = File.read(File.join(base_path, 'messages/_queued_message.html.erb'))
    expect(queued_message).to include('id="queued_message_<%= queued_message.id %>"')
    expect(queued_message).to include("#{path_helper}(chat, queued_message)")
    expect(queued_message).to include('method: :delete')
    chat_show = File.read(File.join(base_path, 'chats/show.html.erb'))
    expect(chat_show).to include('.queued_messages.each do |queued_message|')
    create_stream = File.read(File.join(base_path, 'messages/create.turbo_stream.erb'))
    expect(create_stream).to include('turbo_stream.refresh request_id: nil')
    expect(create_stream).not_to include('turbo_stream.append')
  end

  def expect_routes(path, namespaced: false)
    routes_content = File.read(path)
    expect(routes_content).to include('resources :chats')
    expect(routes_content).to include('resources :messages, only: [ :create ]')
    expect(routes_content).to include('resources :answers, only: [ :create ]')
    expect(routes_content).to include('resources :queued_messages, only: [ :destroy ]')
    expect(routes_content).to include('post :cancel, on: :member')
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

  def expect_job_file(path:, class_name:, perform_line:, complete_line:, requeue_line:)
    job_content = File.read(path)
    expect(job_content).to include(class_name)
    expect(job_content).to include(perform_line)
    expect(job_content).to include(complete_line)
    expect(job_content).to include(requeue_line)
    expect(job_content).to include('discard_on RubyLLM::CancelledError')
    expect(job_content).not_to include('reply_error', 'rescue', 'broadcast_refresh', 'perform_later', 'queued_messages')
    expect(job_content.lines.size).to eq(9)
  end

  # The script sends requests through the app, and each request resets
  # the execution context a wrapping executor would still be using.
  def run_rails_runner_outside_executor(script)
    run_rails('runner', '--skip-executor', script)
  end

  def give_chat_agent_tools_that_ask(agent_path)
    FileUtils.mkdir_p('app/tools')
    File.write('app/tools/send_mail_tool.rb', <<~RUBY)
      class SendMailTool < RubyLLM::Tool
        description "Sends an email"
        parameter :to, description: "The recipient"
        requires_approval

        def execute(to:) = "Sent to \#{to}"
      end
    RUBY
    File.write('app/tools/pick_seat_tool.rb', <<~RUBY)
      class PickSeatTool < RubyLLM::Tool
        description "Picks a seat"

        def execute = "Seat \#{ask("Window or aisle?", choices: %w[window aisle])}"
      end
    RUBY
    agent = File.read(agent_path)
    return if agent.include?('SendMailTool')

    File.write(agent_path, agent.sub(/^end\n\z/, "  tools SendMailTool, PickSeatTool\nend\n"))
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
      abort "running page lacks Thinking…" unless html.include?("Thinking…")
      abort "running page lacks the form" unless html.include?('name="#{message_key}[content]"')

      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host! "localhost"
      jobs = -> { ActiveJob::Base.queue_adapter.enqueued_jobs.select { |job| job["job_class"] == "#{job}" } }
      session.post "#{chats_path}/\#{chat.id}/messages", params: { #{message_key}: { content: "Use the EU file" } }
      abort "message answered \#{session.response.status}" unless session.response.status == 302
      queued = chat.queued_messages.to_a
      abort "queued \#{queued.map(&:content)}" unless queued.map(&:content) == [ "Use the EU file" ]
      enqueued = jobs.call.map { |job| [ job["arguments"], job["scheduled_at"] ] }
      abort "the queued message has no job at once: \#{enqueued}" unless enqueued == [ [ [ chat.id ], nil ] ]
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      html = #{controller}.render(:show, assigns: #{assigns})
      [ "Use the EU file", "queued_message_\#{queued.first.id}", "Cancel" ].each do |text|
        abort "running page lacks \#{text}" unless html.include?(text)
      end

      stream = { "Accept" => "text/vnd.turbo-stream.html" }
      session.post "#{chats_path}/\#{chat.id}/messages", params: { #{message_key}: { content: "And Q4" } }, headers: stream
      abort "streamed message answered \#{session.response.status}" unless session.response.status == 200
      refresh = '<turbo-stream action="refresh"></turbo-stream>'
      abort "the stream doesn't refresh the page that sent it" unless session.response.body.include?(refresh)
      abort "the streamed message wasn't queued" unless chat.queued_messages.map(&:content).include?("And Q4")

      session.delete "#{chats_path}/\#{chat.id}/queued_messages/\#{queued.first.id}"
      abort "withdraw answered \#{session.response.status}" unless session.response.status == 303
      session.delete "#{chats_path}/\#{chat.id}/queued_messages/\#{queued.first.id}"
      abort "withdrawing again answered \#{session.response.status}" unless session.response.status == 303
      left = chat.queued_messages.map(&:content)
      abort "left queued \#{left}" unless left == [ "And Q4" ]

      abort "a chat with no cost shows one" if #{controller}.render(:show, assigns: #{assigns}).include?("Cost so far")
      reply = chat.add_message(role: :assistant, content: "Priced")
      chat.ruby_llm_usages.create!(operation: "chat", provider: "openai", model: "gpt-test", status: "succeeded",
                                   message: reply, total_cost: 0.0123)
      priced = #{controller}.render(:show, assigns: #{assigns})
      abort "the page lacks the costs" unless priced.scan("$0.0123").size == 2
      abort "running page lacks Stop" unless #{controller}.render(:show, assigns: #{assigns}).match?(/>Stop<|value="Stop"/)
      session.post "#{chats_path}/\#{chat.id}/cancel"
      abort "stop answered \#{session.response.status}" unless session.response.status == 303
      abort "stop did not cancel" unless chat.reload[:cancelled]

      chat.update_columns(claim_token: nil, claimed_until: nil)
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      #{job}.perform_now(chat.id)
      abort "the job left the request" if chat.reload[:cancelled]
      left = chat.queued_messages.map(&:content)
      abort "a stop the next run found took what waits: \#{left}" unless left == [ "And Q4" ]
      abort "a stopped job enqueued another: \#{jobs.call}" if jobs.call.any?
      session.post "#{chats_path}/\#{chat.id}/cancel"
      abort "stopping an idle chat cancelled its next reply" if chat.reload[:cancelled]
      html = #{controller}.render(:show, assigns: #{assigns})
      abort "finished page still thinks" if html.include?("Thinking…")
      abort "finished page still offers Stop" if html.match?(/>Stop<|value="Stop"/)
      abort "finished page lacks the form" unless html.include?('name="#{message_key}[content]"')
      answers = [ true, false ]
      chat.class.prepend(Module.new { define_method(:running?) { answers.empty? ? super() : answers.shift } })
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      session.post "#{chats_path}/\#{chat.id}/messages", params: { #{message_key}: { content: "As the run ends" } }
      released = jobs.call.map { |job| job["scheduled_at"].to_s }
      soon = released.size == 1 && (released.first.empty? || Time.zone.parse(released.first) < 10.seconds.from_now)
      abort "a message queued as the run ended waits a minute: \#{released}" unless soon

      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      session.post "#{chats_path}/\#{chat.id}/messages", params: { #{message_key}: { content: "Hi" } }
      abort "idle message enqueued \#{jobs.call}" unless jobs.call.map { |job| job["arguments"] } == [ [ chat.id ] ]
      abort "idle message not saved" unless chat.reload.to_llm.messages.last.content == "Hi"
      session.post "#{chats_path}/\#{chat.id}/messages", params: { #{message_key}: { content: "Shown at once" } }, headers: stream
      abort "the stream doesn't refresh the page that sent it" unless session.response.body.include?(refresh)
      abort "the sent message isn't saved" unless chat.reload.to_llm.messages.last.content == "Shown at once"

      session.get "#{chats_path}/new"
      abort "new chat page answered \#{session.response.status}" unless session.response.status == 200
      file = Rack::Test::UploadedFile.new(StringIO.new("Quarterly numbers"), "text/plain", original_filename: "q4.txt")
      session.post "#{chats_path}/\#{chat.id}/messages", params: { #{message_key}: { content: "Read this", attachments: [ file ] } }
      attached = chat.reload.to_llm.messages.last.attachments.map(&:filename)
      abort "attached \#{attached}" unless attached == [ "q4.txt" ]

      session.post "#{chats_path}/\#{chat.id}/messages", params: { #{message_key}: { content: "Steal", attachments: [ "/etc/passwd" ] } }
      leaked = chat.reload.to_llm.messages.last
      abort "a path became an attachment" if leaked.content == "Steal" && leaked.attachments.any?
    RUBY
  end

  def question_flow_script(agent:, controller:, assigns:, chats_path:, job:, message_key:, **)
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
        "call_mail" => RubyLLM::ToolCall.new(id: "call_mail", name: "send_mail", arguments: { "to" => "ops" }),
        "call_seat" => RubyLLM::ToolCall.new(id: "call_seat", name: "pick_seat", arguments: {})
      }))
      chat = #{agent}.find(chat.id)
      chat.run_tools
      chat.with_file_store.file_store.write("notes/summary.md", "# Summary")

      html = #{controller}.render(:show, assigns: #{assigns})
      [ "\#{chat.class.name.underscore.tr('/', '_')}_\#{chat.id}_questions", "Approve search_docs?", "refunds",
        "Approve send_mail?", "Window or aisle?", 'value="window"', 'value="aisle"', "Decline",
        "<img", "chart.png", "report.csv", "disposition=attachment",
        '[id="#{message_key}_tool_call_call_search"] { display: none; }',
        '<p id="new_#{message_key}"', "Answer the questions above to continue.",
        "Checking the docs first.", "notes/summary.md" ].each do |text|
        abort "show page lacks \#{text}" unless html.include?(text)
      end
      abort "show page offers the message form" if html.include?('name="#{message_key}[content]"')
      abort "show page hides the call that asked" if html.include?('_tool_call_call_seat"] { display: none; }')

      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host! "localhost"
      stream = { "Accept" => "text/vnd.turbo-stream.html" }
      session.post "#{chats_path}/\#{chat.id}/messages", params: { #{message_key}: { content: "Hi" } }, headers: stream
      abort "message answered \#{session.response.status}" unless session.response.status == 303
      session.post "#{chats_path}/\#{chat.id}/answers", params: { question_id: "call_search" }, headers: stream
      abort "approve answered \#{session.response.status}" unless session.response.status == 200
      abort "approve kept the card" if session.response.body.include?("Approve search_docs?")
      abort "approve continued early" if session.response.body.include?("Continuing the conversation.")
      session.post "#{chats_path}/\#{chat.id}/answers", params: { question_id: "call_mail", decline: true }, headers: stream
      abort "deny answered \#{session.response.status}" unless session.response.status == 200
      abort "deny kept the card" if session.response.body.include?("Approve send_mail?")
      abort "deny kept an approval's call hidden" if session.response.body.include?("display: none")
      seat = #{agent}.find(chat.id).pending_questions.sole
      session.post "#{chats_path}/\#{chat.id}/answers", params: { question_id: seat.id, answer: "middle" }, headers: stream
      abort "a choice not offered answered \#{session.response.status}" unless session.response.status == 303
      abort "a choice not offered said \#{session.flash[:notice]}" unless session.flash[:notice] == '"middle" is not one of the choices: window or aisle.'
      session.post "#{chats_path}/\#{chat.id}/answers", params: { question_id: seat.id, answer: "  " }, headers: stream
      abort "a blank answer said \#{session.flash[:notice]}" unless session.flash[:notice] == "The question needs an answer."
      session.get "#{chats_path}/\#{chat.id}"
      abort "show page lacks the refusal" unless session.response.body.include?(">The question needs an answer.</p>")
      session.post "#{chats_path}/\#{chat.id}/answers", params: { question_id: seat.id, answer: " window " }, headers: stream
      abort "answer answered \#{session.response.status}" unless session.response.status == 200
      abort "answer kept the form hidden" unless session.response.body.include?("Continuing the conversation.")

      decisions = RubyLLM::ActiveRecord::ToolCall.where(tool_call_id: %w[call_search call_mail]).pluck(:tool_call_id, :approval).to_h
      abort "decisions \#{decisions}" unless decisions == { "call_search" => "approved", "call_mail" => "denied" }
      answer = RubyLLM::ActiveRecord::ToolCall.find_by!(tool_call_id: "call_seat").mcp_state["requests"].sole["response"]
      abort "answer \#{answer}" unless answer == { "action" => "accept", "content" => { "answer" => "window" } }
      jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |job| job["job_class"] == "#{job}" }
      abort "jobs \#{jobs}" unless jobs.map { |job| job["arguments"] } == [ [ chat.id ] ] * 3
    RUBY
  end

  def oversized_tool_result_script(agent:, **)
    <<~RUBY
      require "ruby_llm/test_helper"
      include RubyLLM::TestHelper

      class LogsTool < RubyLLM::Tool
        description "Returns the application's logs"
      end

      requests = []
      RubyLLM::Provider.prepend(Module.new do
        define_method(:complete) do |messages, **options, &block|
          requests << messages.sum { |message| message.content.to_s.length }
          super(messages, **options, &block)
        end
      end)

      chat = #{agent}.create!.with_tools(LogsTool)
      window = chat.to_llm.model.context_window
      LogsTool.define_method(:execute) { "A log line\n" * window }
      stub_replies tool_call(:logs), "The logs look fine.", "Nothing else."

      chat.ask "What do the logs say?"
      chat.ask "Anything else?"

      abort "sent \#{requests.max} characters for a \#{window}-token window" unless requests.max < window
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

  def model_switch_script(agent:, controller:, assigns:, chats_path:, message_key:, **)
    <<~RUBY
      ActiveJob::Base.queue_adapter = :test
      ActionController::Base.allow_forgery_protection = false
      default = RubyLLM.models.find(RubyLLM.config.default_model)
      other = RubyLLM.models.chat_models.by_provider(default.provider).all.find { |candidate| candidate.id != default.id }
      chat = #{agent}.create!
      selected = ->(html) { html[/<option selected="selected" value="([^"]*)"/, 1] }
      shown = selected.(#{controller}.render(:show, assigns: #{assigns}))
      abort "the form selects \#{shown}" unless shown == "\#{default.provider}:\#{default.id}"

      switches = []
      chat.class.prepend(Module.new { define_method(:with_model) { |*args, **options| switches << args; super(*args, **options) } })
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host! "localhost"
      send_message = lambda do |model|
        params = { #{message_key}: { content: "Hi", model: model }.compact }
        session.post "#{chats_path}/\#{chat.id}/messages", params:, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        abort "the message answered \#{session.response.status}" unless session.response.status == 200
        chat.reload
      end

      choice = "\#{other.provider}:\#{other.id}"
      send_message.(choice)
      abort "the chat uses \#{chat.model_id}" unless chat.model_id == other.id && chat.provider == other.provider
      abort "the new form selects \#{selected.(session.response.body)}" unless selected.(session.response.body) == choice
      shown = selected.(#{controller}.render(:show, assigns: #{assigns}))
      abort "the page selects \#{shown}" unless shown == choice

      send_message.(choice)
      send_message.(nil)
      abort "switched for an unchanged model: \#{switches}" unless switches == [ [ other.id ] ]

      send_message.("")
      abort "the default entry left \#{chat.model_id}" unless chat.model_id == default.id
    RUBY
  end

  def job_retry_script(agent:, controller:, assigns:, chats_path:, job:, message_key:, **)
    <<~RUBY
      ActiveJob::Base.queue_adapter = :test
      ActionController::Base.allow_forgery_protection = false
      chat = #{agent}.create!
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host! "localhost"
      session.post "#{chats_path}/\#{chat.id}/messages", params: { #{message_key}: { content: "Hi" } }
      jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |job| job["job_class"] == "#{job}" }
      abort "jobs \#{jobs}" unless jobs.map { |job| job["arguments"] } == [ [ chat.id ] ]

      attempts = 0
      failures = [ RubyLLM::ServerError.new("The model is overloaded"), nil, RubyLLM::ContextLengthExceededError.new("no") ]
      RubyLLM::Chat.prepend(Module.new do
        define_method(:complete) do |&_block|
          failure = failures[attempts]
          attempts += 1
          raise failure if failure

          add_message(role: :assistant, content: "Hello")
        end
      end)
      perform = lambda do
        #{job}.perform_now(chat.id)
      rescue RubyLLM::Error
        nil
      end

      perform.call
      chat.reload
      html = #{controller}.render(:show, assigns: #{assigns})
      abort "the failed reply's page lacks its error" unless html.include?("The reply failed. Send your message again.")
      perform.call
      abort "the next reply kept the error: \#{chat.reload.reply_error}" if chat.reload.reply_error
      abort "the page still shows the error" if #{controller}.render(:show, assigns: #{assigns}).include?("The reply failed")

      asked = chat.reload.#{message_key}s.where(role: "user").pluck(:content)
      abort "asked \#{asked} in \#{attempts} attempts" unless attempts == 2 && asked == [ "Hi" ]

      perform.call
      abort "error lacks advice: \#{chat.reload.reply_error}" unless chat.reload.reply_error.include?("too long")
    RUBY
  end

  def dead_holder_script(agent:, chats_path:, job:, message_key:, **)
    <<~RUBY
      require "ruby_llm/test_helper"
      require "active_support/testing/time_helpers"
      include RubyLLM::TestHelper
      include ActiveSupport::Testing::TimeHelpers
      ActiveJob::Base.queue_adapter = :test
      ActionController::Base.allow_forgery_protection = false
      chat = #{agent}.create!
      chat.add_message(role: :user, content: "Hello")
      chat.update_columns(claim_token: "died", claimed_until: 1.minute.from_now)

      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host! "localhost"
      session.post "#{chats_path}/\#{chat.id}/messages", params: { #{message_key}: { content: "Are you there?" } }
      queued = chat.queued_messages.map(&:content)
      abort "a message to a chat a run that died holds wasn't queued: \#{queued}" unless queued == [ "Are you there?" ]

      stub_replies "Here I am"
      enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs
      ActiveJob::Base.execute(enqueued.shift)
      retried = enqueued.shift
      abort "the job that found the chat held didn't try again: \#{retried}" unless retried&.dig("job_class") == "#{job}"
      at = Time.zone.parse(retried["scheduled_at"])
      expires = chat.reload.claimed_until
      abort "the retry at \#{at} isn't right after the claim expires at \#{expires}" unless at.between?(expires, expires + 30.seconds)
      travel_to(at + 1.second) { ActiveJob::Base.execute(retried) }
      answer = chat.reload.to_llm.messages.last.content
      abort "the retry didn't answer: \#{answer}" unless answer == "Here I am"
    RUBY
  end

  def killed_reply_script(agent:, marker:, **)
    <<~RUBY
      require "ruby_llm/test_helper"
      include RubyLLM::TestHelper
      stub_replies (1..400).map { |word| "word\#{word}" }.join(" "), interval: 0.05
      chat = #{agent}.create!
      chat.ask("Hello") { File.write("#{marker}", chat.id.to_s) unless File.exist?("#{marker}") }
    RUBY
  end

  def boot_again_script(agent:, job:, resume_job:, chat_id:, **)
    model = agent.delete_suffix('Agent')
    <<~RUBY
      require "ruby_llm/test_helper"
      require "active_support/testing/time_helpers"
      include RubyLLM::TestHelper
      include ActiveSupport::Testing::TimeHelpers
      ActiveJob::Base.queue_adapter = :test
      abort "the killed reply isn't held until its claim expires" unless #{model}.find(#{chat_id}).running?
      abort "a held chat counts as interrupted" if #{model}.interrupted.exists?(#{chat_id})

      Rails.application.load_server
      jobs = ActiveJob::Base.queue_adapter.enqueued_jobs
      boot = jobs.find { |enqueued| enqueued["job_class"] == "#{resume_job}" }
      abort "booting didn't schedule #{resume_job}: \#{jobs}" unless boot
      at = Time.zone.parse(boot["scheduled_at"])
      abort "the boot sweep at \#{at} runs before the claims expire" unless at > 50.seconds.from_now

      stub_replies "Picked up again"
      travel_to(at + 1.second) do
        ActiveJob::Base.execute(boot)
        reply = jobs.find { |enqueued| enqueued["job_class"] == "#{job}" }
        abort "#{resume_job} didn't queue the reply: \#{jobs}" unless reply&.dig("arguments") == [ #{chat_id} ]
        ActiveJob::Base.execute(reply)
      end
      answer = #{agent}.find(#{chat_id}).to_llm.messages.last.content
      abort "the reply didn't complete: \#{answer}" unless answer == "Picked up again"
      abort "a complete chat counts as interrupted" if #{model}.interrupted.exists?(#{chat_id})
    RUBY
  end

  def spawn_rails_runner(script, log)
    env = {
      'BUNDLE_GEMFILE' => ENV['BUNDLE_GEMFILE'] || Bundler.default_gemfile.to_s,
      'BUNDLE_IGNORE_CONFIG' => '1',
      'OPENAI_API_KEY' => ENV.fetch('OPENAI_API_KEY', 'test')
    }
    Process.spawn(env, 'bundle', 'exec', 'rails', 'runner', script, out: log, err: log)
  end

  def kill_mid_reply(agent_options)
    marker = File.expand_path('tmp/killed_reply')
    FileUtils.rm_f(marker)
    log = File.expand_path('tmp/killed_reply.log')
    pid = spawn_rails_runner(killed_reply_script(**agent_options, marker:), log)
    deadline = Time.now + 60
    sleep 0.1 until File.exist?(marker) || Time.now > deadline
    Process.kill('KILL', pid)
    Process.wait(pid)
    expect(File.exist?(marker)).to be(true), File.read(log)
    File.read(marker).to_i
  end

  def expect_chat_script_to_succeed(script)
    success, output = run_rails_runner(script)
    expect(success).to be(true), output
  end

  describe 'with a destination other than the working directory' do
    let(:destination) { Dir.mktmpdir('ruby_llm_chat_ui') }
    let(:generator) { described_class.new([], {}, destination_root: destination, shell: Thor::Shell::Basic.new) }

    before do
      allow(generator.shell).to receive(:say_status)
      { 'app/models/message.rb' => plain_message_model,
        'app/controllers/application_controller.rb' => "class ApplicationController\nend\n" }.each do |path, content|
        FileUtils.mkdir_p(File.dirname(File.join(destination, path)))
        File.write(File.join(destination, path), content)
      end
    end

    after { FileUtils.remove_entry(destination) }

    it 'finds the message model there' do
      expect { generator.check_model_exists }.not_to raise_error
    end

    describe 'scheduling the resume job' do
      def recurring_path = File.join(destination, 'config/recurring.yml')

      def cleanup
        "  clear_jobs:\n    command: \"SolidQueue::Job.clear_finished_in_batches\"\n    schedule: every hour\n"
      end

      before do
        FileUtils.mkdir_p(File.join(destination, 'config/environments'))
        %w[development production test].each do |environment|
          File.write(File.join(destination, "config/environments/#{environment}.rb"), '')
        end
      end

      def schedule(source, times: 2)
        File.write(recurring_path, source)
        times.times { generator.schedule_resume_job }
        ActiveSupport::ConfigurationFile.parse(recurring_path)
      end

      def resume_tasks(tasks)
        tasks.values.select { |task| task.is_a?(Hash) && task['class'] == 'ResumeInterruptedChatsJob' }
      end

      it 'adds it once under production, as Rails writes the file' do
        config = schedule("# examples:\n#   periodic_cleanup:\n\nproduction:\n#{cleanup}")

        expect(resume_tasks(config['production'])).to eq([{ 'class' => 'ResumeInterruptedChatsJob',
                                                            'schedule' => 'every minute' }])
        expect(config['production']).to include('clear_jobs')
      end

      it 'adds it under headers with a comment or an anchor' do
        config = schedule("development: &shared\n#{cleanup}\nproduction: # servers\n#{cleanup}")

        expect(%w[development production].map { |environment| resume_tasks(config[environment]).size }).to eq([1, 1])
      end

      it 'adds it to a production that aliases another environment, keeping what it had' do
        config = schedule("development: &shared\n#{cleanup}\nproduction: *shared\n")

        expect(resume_tasks(config['production']).size).to eq(1)
        expect(config['production']).to include('clear_jobs')
        expect(resume_tasks(config['development']).size).to eq(1)
      end

      it 'adds production to a file that only names development' do
        config = schedule("development:\n#{cleanup}")

        expect(%w[development production].map { |environment| resume_tasks(config[environment]).size }).to eq([1, 1])
      end

      it 'adds it at the top of a file without environments' do
        config = schedule(cleanup.gsub(/^  /, ''))

        expect(resume_tasks(config).size).to eq(1)
        expect(config).to include('clear_jobs')
      end

      it 'adds it under the environment, not a comment or key that ends with its name' do
        config = schedule("# production:\nother_production:\n#{cleanup}\nproduction:\n#{cleanup}")

        expect(resume_tasks(config['production']).size).to eq(1)
        expect(resume_tasks(config['other_production'])).to be_empty
      end

      it 'leaves a file it cannot read alone, and says so' do
        source = "production:\n  clear_jobs: [unclosed\n"
        File.write(recurring_path, source)
        allow(generator).to receive(:say_status).and_call_original

        generator.schedule_resume_job

        expect(File.read(recurring_path)).to eq(source)
        expect(generator).to have_received(:say_status).with(:skip, /add ResumeInterruptedChatsJob/, :yellow)
      end

      it 'removes it on destroy' do
        source = "development: &shared\n#{cleanup}\nproduction: # servers\n#{cleanup}"
        schedule(source, times: 1)
        generator.behavior = :revoke
        generator.schedule_resume_job

        expect(File.read(recurring_path)).to eq(source)
      end
    end

    it 'warns when config.ru never loads the server hooks the boot run needs' do
      File.write(File.join(destination, 'config.ru'), "run Rails.application\n")
      allow(generator).to receive(:say_status).and_call_original

      generator.resume_on_boot

      expect(generator).to have_received(:say_status).with(:warn, /load_server/, :yellow)
    end

    it 'adds available_chat_models to the application controller there' do
      generator.add_available_chat_models_to_application_controller

      expect(File.read(File.join(destination, 'app/controllers/application_controller.rb')))
        .to include('def available_chat_models')
    end

    def initializer_with(lines)
      path = File.join(destination, 'config/initializers/ruby_llm.rb')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "RubyLLM.configure do |config|\n#{lines}end\n")
      generator.context_budget
      File.read(path)
    end

    it 'gives an initializer without a context budget the one new apps get' do
      expect(initializer_with("  config.openai_api_key = nil\n")).to eq(<<~RUBY)
        RubyLLM.configure do |config|
          config.openai_api_key = nil
          config.context_budget = { per_result: 0.25, per_request: 0.7 }
        end
      RUBY
    end

    it 'leaves a context budget the initializer sets, or turns off, alone' do
      ["  config.context_budget = { per_request: 0.5 }\n", "  config.context_budget = nil\n"].each do |line|
        expect(initializer_with(line)).to eq("RubyLLM.configure do |config|\n#{line}end\n")
      end
    end

    it 'adds it inside the configure block, with its block variable' do
      path = File.join(destination, 'config/initializers/ruby_llm.rb')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path,
                 "module Tracing\nend\n\nRubyLLM.configure do |c|\n  c.openai_api_key = nil\nend\n\nTracing.start\n")

      generator.context_budget

      expect(File.read(path)).to eq(<<~RUBY)
        module Tracing
        end

        RubyLLM.configure do |c|
          c.openai_api_key = nil
          c.context_budget = { per_result: 0.25, per_request: 0.7 }
        end

        Tracing.start
      RUBY
    end

    def initializer_after_generating(source)
      path = File.join(destination, 'config/initializers/ruby_llm.rb')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, source)
      generator.context_budget
      File.read(path)
    end

    it 'leaves a context budget set through RubyLLM.config alone' do
      source = "RubyLLM.config.context_budget = { per_request: 0.5 }\nRubyLLM.configure do |config|\nend\n"

      expect(initializer_after_generating(source)).to eq(source)
    end

    it 'adds it when only an unrelated method assigns the same name' do
      source = "def tune(config)\n  config.context_budget = nil\nend\n\nRubyLLM.configure do |config|\nend\n"

      expect(initializer_after_generating(source)).to end_with(<<~RUBY)
        RubyLLM.configure do |config|
          config.context_budget = { per_result: 0.25, per_request: 0.7 }
        end
      RUBY
    end

    it 'leaves the file alone when a heredoc holds what looks like the block' do
      allow(generator).to receive(:say)

      ["RubyLLM.configure do |config|\n  config.openai_api_key = <<~KEY\nend\nKEY\nend\n",
       "example = <<~TEXT\nRubyLLM.configure do |config|\nTEXT\n1.times do\nend\n"].each do |source|
        expect(initializer_after_generating(source)).to eq(source)
      end
      expect(generator).to have_received(:say).with(/\AAdd config\.context_budget = /, :yellow).twice
    end

    it 'says what to add without a configure block it can find' do
      path = File.join(destination, 'config/initializers/ruby_llm.rb')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "RubyLLM.config.openai_api_key = nil\n")
      allow(generator).to receive(:say)

      generator.context_budget

      expect(File.read(path)).to eq("RubyLLM.config.openai_api_key = nil\n")
      expect(generator).to have_received(:say).with(/\AAdd config\.context_budget = /, :yellow)
    end

    it 'says what to add without an initializer' do
      allow(generator).to receive(:say)

      generator.context_budget

      line = 'config.context_budget = { per_result: 0.25, per_request: 0.7 }'
      expect(generator).to have_received(:say).with("Add #{line} to your RubyLLM configuration", :yellow)
    end
  end

  {
    'with default model names' => {
      app_name: 'test_app_default',
      template_name: 'default_models_template.rb',
      generator_args: [],
      controller_example: 'creates controller files with default names',
      controller_paths: %w[
        app/controllers/chats_controller.rb
        app/controllers/messages_controller.rb
        app/controllers/models_controller.rb
        app/controllers/answers_controller.rb
        app/controllers/queued_messages_controller.rb
      ],
      helper_path: 'app/helpers/messages_helper.rb',
      view_example: 'creates view files with default paths',
      view_options: {
        base_path: 'app/views',
        chats_target: 'new_message',
        chat_views_path: 'chats',
        chat: 'chat',
        form_partial_path: 'messages/form',
        model_index_collection: 'models',
        model_partial_path: 'models/model',
        questions_base_path: 'app/views/questions',
        answers_base_path: 'app/views/answers',
        answers_path_helper: 'chat_answers_path'
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
        "@message = Message.new\n    @chat_models = available_chat_models\n",
        '@chat = Chat.new',
        '@chat_models = available_chat_models',
        'prompt = params.dig(:chat, :prompt)',
        'if prompt.present? || attachments',
        '@chat.ask_later(prompt.presence, with: attachments)',
        'ChatResponseJob.set(wait: 1.second).perform_later(@chat.id)',
        'provider, model = params.dig(:chat, :model).to_s.split(":", 2)',
        '@chat = ChatAgent.create!(**{ model: model.presence, provider: provider.presence }.compact)',
        '@chat.errors.add(:prompt, "can\'t be blank")',
        'render :new, status:'
      ],
      messages_controller_path: 'app/controllers/messages_controller.rb',
      messages_controller_expectations: [
        'class MessagesController',
        '@chat = ChatAgent.find(params[:chat_id])',
        'rescue_from RubyLLM::PendingToolCallsError',
        'params.dig(:message, :content).presence',
        "@chat_models = available_chat_models\n    if content || attachments\n      switch_model\n      " \
        "@chat.ask_later(content, with: attachments)\n      ChatResponseJob.perform_later(@chat.id)\n",
        'selected = params.dig(:message, :model)',
        'return if selected.nil? || selected == [ @chat.provider, @chat.model_id ].compact.join(":")',
        '@chat.with_model(model, provider: provider)',
        'format.turbo_stream',
        '@message = @chat.messages.build',
        '@message.errors.add(:content, "can\'t be blank")',
        'render "chats/show", status:'
      ],
      queued_messages_controller_path: 'app/controllers/queued_messages_controller.rb',
      queued_messages_controller_expectations: [
        'class QueuedMessagesController',
        '@chat = ChatAgent.find(params[:chat_id])',
        '@chat.queued_messages.find_by(id: params[:id])&.withdraw',
        'redirect_to @chat, status: :see_other'
      ],
      answers_controller_path: 'app/controllers/answers_controller.rb',
      answers_controller_expectations: [
        'class AnswersController',
        '@chat = ChatAgent.find(params[:chat_id])',
        '@chat.decline(params[:question_id])',
        '@chat.answer(params[:question_id], params[:answer])',
        'ChatResponseJob.perform_later(@chat.id)',
        'rescue_from RubyLLM::ToolCallRunningError',
        'notice: error.message, status: :see_other'
      ],
      approval_flow: {
        agent: 'ChatAgent', agent_path: 'app/agents/chat_agent.rb', controller: 'ChatsController',
        assigns: '{ chat: chat, message: Message.new, chat_models: RubyLLM.models.chat_models.all }',
        chats_path: '/chats',
        job: 'ChatResponseJob', message_key: 'message', resume_job: 'ResumeInterruptedChatsJob'
      },
      resume_job_path: 'app/jobs/resume_interrupted_chats_job.rb',
      resume_job_source: <<~RUBY,
        class ResumeInterruptedChatsJob < ApplicationJob
          def perform = Chat.interrupted.find_each { |chat| ChatResponseJob.perform_later(chat.id) }
        end
      RUBY
      resume_boot_path: 'config/initializers/resume_interrupted_chats.rb',
      models_controller_path: 'app/controllers/models_controller.rb',
      models_controller_expectations: [
        'class ModelsController',
        '@models = available_chat_models'
      ],
      job_example: 'job references correct model classes',
      job_options: {
        path: 'app/jobs/chat_response_job.rb',
        class_name: 'class ChatResponseJob',
        perform_line: 'def perform(chat_id)',
        complete_line: 'chat.complete(&:broadcast)',
        requeue_line: 'retry_job wait: 1.minute if chat.running?'
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
      generator_args: %w[chat:Llm::Chat message:Llm::Message],
      controller_example: 'creates controller files with namespaced paths',
      controller_paths: %w[
        app/controllers/llm/chats_controller.rb
        app/controllers/llm/messages_controller.rb
        app/controllers/llm/models_controller.rb
        app/controllers/llm/answers_controller.rb
        app/controllers/llm/queued_messages_controller.rb
      ],
      helper_path: 'app/helpers/llm/messages_helper.rb',
      view_example: 'creates view files with namespaced paths',
      view_options: {
        base_path: 'app/views/llm',
        chats_target: 'new_llm_message',
        chat_views_path: 'llm/chats',
        chat: 'llm_chat',
        form_partial_path: 'llm/messages/form',
        model_index_collection: 'llm_models',
        model_partial_path: 'llm/models/model',
        questions_base_path: 'app/views/llm/questions',
        answers_base_path: 'app/views/llm/answers',
        answers_path_helper: 'llm_chat_answers_path'
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
        "@llm_message = Llm::Message.new\n    @chat_models = available_chat_models\n",
        '@llm_chat = Llm::Chat.new',
        '@chat_models = available_chat_models',
        'prompt = params.dig(:llm_chat, :prompt)',
        'if prompt.present? || attachments',
        'provider, model = params.dig(:llm_chat, :model).to_s.split(":", 2)',
        '@llm_chat = Llm::ChatAgent.create!(**{ model: model.presence, provider: provider.presence }.compact)',
        '@llm_chat.errors.add(:prompt, "can\'t be blank")',
        'render :new, status:'
      ],
      messages_controller_path: 'app/controllers/llm/messages_controller.rb',
      messages_controller_expectations: [
        'class Llm::MessagesController',
        '@llm_chat = Llm::ChatAgent.find(params[:chat_id])',
        'rescue_from RubyLLM::PendingToolCallsError',
        'params.dig(:llm_message, :content).presence',
        "@chat_models = available_chat_models\n    if content || attachments\n      switch_model\n      " \
        "@llm_chat.ask_later(content, with: attachments)\n      LlmChatResponseJob.perform_later(@llm_chat.id)\n",
        'selected = params.dig(:llm_message, :model)',
        'return if selected.nil? || selected == [ @llm_chat.provider, @llm_chat.model_id ].compact.join(":")',
        '@llm_chat.with_model(model, provider: provider)',
        'format.turbo_stream',
        '@llm_message = @llm_chat.llm_messages.build',
        '@llm_message.errors.add(:content, "can\'t be blank")',
        'render "llm/chats/show", status:'
      ],
      queued_messages_controller_path: 'app/controllers/llm/queued_messages_controller.rb',
      queued_messages_controller_expectations: [
        'class Llm::QueuedMessagesController',
        '@llm_chat = Llm::ChatAgent.find(params[:chat_id])',
        '@llm_chat.queued_messages.find_by(id: params[:id])&.withdraw',
        'redirect_to @llm_chat, status: :see_other'
      ],
      answers_controller_path: 'app/controllers/llm/answers_controller.rb',
      answers_controller_expectations: [
        'class Llm::AnswersController',
        '@llm_chat = Llm::ChatAgent.find(params[:chat_id])',
        '@llm_chat.decline(params[:question_id])',
        '@llm_chat.answer(params[:question_id], params[:answer])',
        'LlmChatResponseJob.perform_later(@llm_chat.id)',
        'rescue_from RubyLLM::ToolCallRunningError',
        'notice: error.message, status: :see_other'
      ],
      approval_flow: {
        agent: 'Llm::ChatAgent', agent_path: 'app/agents/llm/chat_agent.rb', controller: 'Llm::ChatsController',
        assigns: '{ llm_chat: chat, llm_message: Llm::Message.new, chat_models: RubyLLM.models.chat_models.all }',
        chats_path: '/llm/chats',
        job: 'LlmChatResponseJob', message_key: 'llm_message', resume_job: 'ResumeInterruptedLlmChatsJob'
      },
      resume_job_path: 'app/jobs/resume_interrupted_llm_chats_job.rb',
      resume_job_source: <<~RUBY,
        class ResumeInterruptedLlmChatsJob < ApplicationJob
          def perform = Llm::Chat.interrupted.find_each { |llm_chat| LlmChatResponseJob.perform_later(llm_chat.id) }
        end
      RUBY
      resume_boot_path: 'config/initializers/resume_interrupted_llm_chats.rb',
      models_controller_path: 'app/controllers/llm/models_controller.rb',
      models_controller_expectations: [
        'class Llm::ModelsController',
        '@llm_models = available_chat_models'
      ],
      job_example: 'job references correct namespaced model classes',
      job_options: {
        path: 'app/jobs/llm_chat_response_job.rb',
        class_name: 'class LlmChatResponseJob',
        perform_line: 'def perform(llm_chat_id)',
        complete_line: 'llm_chat.complete(&:broadcast)',
        requeue_line: 'retry_job wait: 1.minute if llm_chat.running?'
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
        expect(show_view).to include('render "llm/chats/questions", chat: @llm_chat')

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
      let(:app_path) { GeneratorTestHelpers.app_path(config[:app_name]) }

      before(:all) do # rubocop:disable RSpec/BeforeAfterAll
        GeneratorTestHelpers.cleanup_test_app(GeneratorTestHelpers.app_path(config[:app_name]))
        GeneratorTestHelpers.create_test_app(
          config[:app_name],
          template: config[:template_name],
          template_path: File.expand_path('../../fixtures/templates', __dir__)
        )
      end

      after(:all) do # rubocop:disable RSpec/BeforeAfterAll
        GeneratorTestHelpers.cleanup_test_app(GeneratorTestHelpers.app_path(config[:app_name]))
      end

      it config[:controller_example] do
        within_test_app(app_path) do
          config[:controller_paths].each do |path|
            expect(File.exist?(path)).to be true
          end

          expect(File.exist?(config[:helper_path])).to be(false)
          expect(Dir['app/helpers/**/*_helper.rb']).to eq(['app/helpers/application_helper.rb'])
        end
      end

      it config[:view_example] do
        within_test_app(app_path) do
          expect_generated_view_set(**config[:view_options])
          chat_show = File.read(File.join(config[:view_options][:base_path], 'chats/show.html.erb'))
          expect(chat_show).to include('turbo_frame_tag "', '.reply_error.present?')
          expect(chat_show).not_to include('data-turbo-permanent')
        end
      end

      if description == 'with default model names'
        it 'says what an app without Hotwire needs' do
          within_test_app(app_path) do
            Dir.mktmpdir do |destination|
              FileUtils.cp_r("#{app_path}/.", destination)
              within_test_app(destination) do
                gemfile = File.read('Gemfile').lines.reject { |line| line.include?('turbo-rails') }.join
                File.write('Gemfile', gemfile)
                FileUtils.rm(Dir['db/migrate/*_add_reply_error_to_chats.rb'])
                output, = run_rails_generate('ruby_llm:chat_ui', '--skip', chdir: destination)
                expect(output.lines.last.strip)
                  .to eq('Add turbo-rails and stimulus-rails, which the chat UI runs on, then run bin/rails db:migrate')
              end
            end
          end
        end

        it 'prints the files it creates and the migration to run, and no guide' do
          within_test_app(app_path) do
            Dir.mktmpdir do |destination|
              FileUtils.cp_r("#{app_path}/.", destination)
              within_test_app(destination) do
                File.write('Gemfile', %(#{File.read('Gemfile')}gem "turbo-rails"\n))
                FileUtils.rm(Dir['db/migrate/*_add_reply_error_to_chats.rb'])
                output, status = run_rails_generate('ruby_llm:chat_ui', '--skip', chdir: destination)
                expect(status.success?).to be(true), output
                expect(output).to include('app/agents/chat_agent.rb', 'add_reply_error_to_chats.rb')
                expect(output.lines.last.strip).to eq('Run bin/rails db:migrate')
                expect(output).not_to include('Works now', 'Where it lives', 'file_store', 'TestHelper')

                output, = run_rails_generate('ruby_llm:chat_ui', '--skip', chdir: destination)
                expect(output).not_to include('db:migrate')
              end
            end
          end
        end

        it 'generates a system test that uses the test helper' do
          within_test_app(app_path) do
            test_file = File.read('test/system/chats_test.rb')
            expect(test_file).to include('include RubyLLM::TestHelper', 'click_on "Stop"',
                                         'ChatResponseJob.queue_adapter', 'with_extra_message_fields',
                                         'select_tag "message[tone]"', 'switching the model mid-conversation',
                                         'replies.map(&:model_id)')
            expect(File.exist?('test/application_system_test_case.rb')).to be(true)
          end
        end

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

        it 'loads the Stimulus controller from the gem in an importmap app, without pinning anything' do
          Dir.mktmpdir do |destination|
            FileUtils.cp_r("#{app_path}/.", destination)
            within_test_app(destination) do
              File.write('Gemfile', %(#{File.read('Gemfile')}gem "importmap-rails"\n))
              File.write('config/importmap.rb', %(pin "application"\n))
              File.write('bin/importmap', "#!/bin/sh\necho \"$@\" >> tmp/importmap_calls\n")
              FileUtils.chmod('+x', 'bin/importmap')

              output, status = run_rails_generate('ruby_llm:chat_ui', '--force', chdir: destination)
              expect(status.success?).to be(true), output
              expect(File.read('app/javascript/controllers/chat_message_controller.js'))
                .to eq(%(export { default } from "ruby_llm/chat_message_controller"\n))
              expect(File.exist?('tmp/importmap_calls')).to be(false)
              expect(File.read('config/importmap.rb')).to eq(%(pin "application"\n))
              expect(output).not_to include('yarn add', 'plain text')
            end
          end
        end

        it 'copies the controller for the bundler in an app with both jsbundling-rails and importmap-rails' do
          Dir.mktmpdir do |destination|
            FileUtils.cp_r("#{app_path}/.", destination)
            within_test_app(destination) do
              File.write('Gemfile', %(#{File.read('Gemfile')}gem "importmap-rails"\ngem "jsbundling-rails"\n))
              File.write('package.json', '{}')

              output, status = run_rails_generate('ruby_llm:chat_ui', '--force', chdir: destination)
              expect(status.success?).to be(true), output
              controller = File.read(RubyLLM::Generators::ChatUIGenerator::CONTROLLER)
              expect(File.read('app/javascript/controllers/chat_message_controller.js')).to eq(controller)
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
              expect(Dir['db/migrate/*_add_reply_error_to_chats.rb'].size).to eq(1)
              initializer = File.read('config/initializers/ruby_llm.rb')
              expect(initializer.scan('config.broadcast_messages = true').size).to eq(1)
              expect(initializer.scan('config.context_budget =').size).to eq(1)
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
              expect(output).to include('acts_as_message broadcasts: false')
            end
          end
        end

        it 'copies the controller for a jsbundling app, and leaves its packages to the guide' do
          Dir.mktmpdir do |destination|
            FileUtils.cp_r("#{app_path}/.", destination)
            within_test_app(destination) do
              File.write('Gemfile', %(#{File.read('Gemfile')}gem "jsbundling-rails"\n))
              File.write('package.json', '{}')
              File.write('config/importmap.rb', %(pin "application"\n))
              output, status = run_rails_generate('ruby_llm:chat_ui', '--force', chdir: destination)
              expect(status.success?).to be(true), output
              expect(output).not_to include('yarn add', 'stimulus:manifest:update', 'importmap')
              expect(output.lines.last.strip).to eq('Add turbo-rails and stimulus-rails, which the chat UI runs on')

              javascripts = File.expand_path('../../../app/assets/javascripts/ruby_llm', __dir__)
              expect(File.read('app/javascript/controllers/chat_message_controller.js'))
                .to eq(File.read(File.join(javascripts, 'chat_message_controller.js')))
              expect(File.read(File.join(javascripts, 'marked.js'))).to start_with('// marked@18.0.14 ')
              expect(File.read(File.join(javascripts, 'dompurify.js'))).to start_with('// dompurify@3.4.16 ')
            end
          end
        end

        it 'trusts an ApplicationAgent that still says chat_model' do
          Dir.mktmpdir do |destination|
            FileUtils.cp_r("#{app_path}/.", destination)
            within_test_app(destination) do
              File.write('app/agents/application_agent.rb',
                         "class ApplicationAgent < RubyLLM::Agent\n  chat_model Chat\nend\n")

              output, status = run_rails_generate('ruby_llm:chat_ui', '--force', chdir: destination)
              expect(status.success?).to be(true), output
              expect(File.read('app/agents/chat_agent.rb')).to eq(<<~RUBY)
                class ChatAgent < ApplicationAgent
                  caching
                end
              RUBY
            end
          end
        end

        it "keeps the ApplicationAgent's caching policy" do
          Dir.mktmpdir do |destination|
            FileUtils.cp_r("#{app_path}/.", destination)
            within_test_app(destination) do
              File.write('app/agents/application_agent.rb',
                         "class ApplicationAgent < RubyLLM::Agent\n  chat_class Chat\n  caching false\nend\n")

              output, status = run_rails_generate('ruby_llm:chat_ui', '--force', chdir: destination)
              expect(status.success?).to be(true), output
              expect(File.read('app/agents/chat_agent.rb')).to eq(<<~RUBY)
                class ChatAgent < ApplicationAgent
                end
              RUBY
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
              expect(File.read('app/agents/chat_agent.rb')).to eq(<<~RUBY)
                class ChatAgent < RubyLLM::Agent
                  chat_class Chat
                  caching
                end
              RUBY
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

      it 'writes a job that resumes interrupted chats, and runs it at boot' do
        within_test_app(app_path) do
          resume_job = config[:approval_flow][:resume_job]
          expect(File.read(config[:resume_job_path])).to eq(config[:resume_job_source])
          expect(File.read(config[:resume_boot_path]))
            .to eq("Rails.application.server { #{resume_job}.set(wait: 1.minute).perform_later }\n")
        end
      end

      it 'schedules the job every minute in each Solid Queue environment, once' do
        within_test_app(app_path) do
          Dir.mktmpdir do |destination|
            FileUtils.cp_r("#{app_path}/.", destination)
            within_test_app(destination) do
              File.write('config/recurring.yml', <<~YAML)
                # examples:
                #   periodic_cleanup:
                #     class: CleanSoftDeletedRecordsJob
                #     schedule: every hour

                development: &development
                  clear_development_jobs:
                    command: "SolidQueue::Job.clear_finished_in_batches"
                    schedule: every day
                  #{config[:resume_job_path].delete_prefix('app/jobs/').delete_suffix('_job.rb')}:
                    class: #{config[:approval_flow][:resume_job]}
                    schedule: every minute

                production: # what runs on the servers
                  clear_solid_queue_finished_jobs:
                    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
                    schedule: every hour at minute 12
              YAML
              2.times do
                output, status = run_rails_generate('ruby_llm:chat_ui', *config[:generator_args], '--skip',
                                                    chdir: destination)
                expect(status.success?).to be(true), output
              end

              resume_job = config[:approval_flow][:resume_job]
              recurring = YAML.load_file('config/recurring.yml')
              %w[development production].each do |environment|
                expect(recurring[environment].values).to include('class' => resume_job, 'schedule' => 'every minute')
              end
              expect(File.read('config/recurring.yml').scan("class: #{resume_job}").size).to eq(2)
            end
          end
        end
      end

      it 'completes a reply killed mid-turn once the app boots again' do
        within_test_app(app_path) do
          chat_id = kill_mid_reply(config[:approval_flow])
          output, status = run_rails_runner_outside_executor(boot_again_script(**config[:approval_flow], chat_id:))
          expect(status.success?).to be(true), output
        end
      end

      it 'adds a column for the reply error to the chats table' do
        within_test_app(app_path) do
          table = config[:approval_flow][:chats_path].delete_prefix('/').tr('/', '_')
          migrations = Dir["db/migrate/*_add_reply_error_to_#{table}.rb"]
          expect(migrations.size).to eq(1)
          expect(File.read(migrations.first)).to include("add_column :#{table}, :reply_error, :string")
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

        it 'nests routes for models under more than one namespace' do
          Dir.mktmpdir do |destination|
            FileUtils.cp_r("#{app_path}/.", destination)
            within_test_app(destination) do
              FileUtils.mkdir_p('app/models/admin/support')
              File.write('app/models/admin/support/message.rb', <<~RUBY)
                class Admin::Support::Message < ApplicationRecord
                end
              RUBY

              output, status = run_rails_generate(
                'ruby_llm:chat_ui', '--ui', 'scaffold',
                'chat:Admin::Support::Chat', 'message:Admin::Support::Message', chdir: destination
              )
              expect(status.success?).to be(true), output

              expect_chat_script_to_succeed(<<~RUBY)
                path = Rails.application.routes.url_helpers.admin_support_chat_messages_path(1)
                abort "messages at \#{path}" unless path == "/admin/support/chats/1/messages"
              RUBY
              expect(File.read('app/views/admin/support/messages/_form.html.erb'))
                .to include('url: admin_support_chat_messages_path(admin_support_chat)')
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
          expect(messages_controller).not_to include('running?', '.queue(', 'suppressing_turbo_broadcasts', 'wait')

          chat_agent = File.read(config[:approval_flow][:agent_path])
          expect(chat_agent).to start_with("class #{config[:approval_flow][:agent]} < ApplicationAgent\n")
          expect(chat_agent).not_to include('chat_class')
          expect(chat_agent).to end_with("  caching\nend\n")
          expect(chat_agent).not_to include('context_budget')

          queued_messages_controller = File.read(config[:queued_messages_controller_path])
          config[:queued_messages_controller_expectations].each do |line|
            expect(queued_messages_controller).to include(line)
          end

          answers_controller = File.read(config[:answers_controller_path])
          config[:answers_controller_expectations].each do |line|
            expect(answers_controller).to include(line)
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
          give_chat_agent_tools_that_ask(config[:approval_flow][:agent_path])
          success, output = run_rails_runner(broadcast_order_script(**config[:approval_flow]))
          expect(success).to be(true), output
        end
      end

      it 'shows Thinking and Stop while a reply runs, and queues the messages sent meanwhile' do
        within_test_app(app_path) do
          output, status = run_rails_runner_outside_executor(running_reply_script(**config[:approval_flow]))
          expect(status.success?).to be(true), output
        end
      end

      it 'switches the model of a chat when a message chooses another' do
        within_test_app(app_path) do
          output, status = run_rails_runner_outside_executor(model_switch_script(**config[:approval_flow]))
          expect(status.success?).to be(true), output
        end
      end

      it 'saves a message once, however often its job runs' do
        within_test_app(app_path) do
          output, status = run_rails_runner_outside_executor(job_retry_script(**config[:approval_flow]))
          expect(status.success?).to be(true), output
        end
      end

      it 'answers a message sent to a chat whose run died, right after its claim expires' do
        within_test_app(app_path) do
          output, status = run_rails_runner_outside_executor(dead_holder_script(**config[:approval_flow]))
          expect(status.success?).to be(true), output
        end
      end

      it 'renders questions, approvals, and attachments, and records answers' do
        within_test_app(app_path) do
          give_chat_agent_tools_that_ask(config[:approval_flow][:agent_path])
          output, status = run_rails_runner_outside_executor(question_flow_script(**config[:approval_flow]))
          expect(status.success?).to be(true), output
        end
      end

      it 'keeps a tool result larger than the context window out of later requests' do
        within_test_app(app_path) do
          output, status = run_rails_runner_outside_executor(oversized_tool_result_script(**config[:approval_flow]))
          expect(status.success?).to be(true), output
        end
      end

      it 'writes an agent test that passes' do
        within_test_app(app_path) do
          test_path = "test/agents/#{config[:approval_flow][:agent_path].delete_prefix('app/agents/')}"
                      .sub(/\.rb\z/, '_test.rb')
          output, status = run_rails('test', test_path, env: { 'RAILS_ENV' => 'test' })
          expect(status.success?).to be(true), output
          expect(output).to match(/1 runs, \d+ assertions, 0 failures, 0 errors/)
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
      let(:app_path) { GeneratorTestHelpers.app_path(app_name) }

      before(:all) do # rubocop:disable RSpec/BeforeAfterAll
        GeneratorTestHelpers.cleanup_test_app(GeneratorTestHelpers.app_path(app_name))
        GeneratorTestHelpers.create_test_app(
          app_name,
          template: template_name,
          template_path: File.expand_path('../../fixtures/templates', __dir__)
        )
      end

      after(:all) do # rubocop:disable RSpec/BeforeAfterAll
        GeneratorTestHelpers.cleanup_test_app(GeneratorTestHelpers.app_path(app_name))
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
