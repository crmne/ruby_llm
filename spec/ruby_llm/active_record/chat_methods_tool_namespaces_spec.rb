# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:anthropic) }
  let(:chat) { Chat.create!(model:, provider: :anthropic) }
  let(:executed) { [] }
  let(:requests) { [] }

  def tool(name, namespace: 'computer', approval: false)
    calls = executed
    klass = Class.new(RubyLLM::Tool)
    klass.define_singleton_method(:tool_name) { name }
    klass.namespace(namespace)
    klass.requires_approval if approval
    klass.define_method(:execute) do
      calls << [namespace, name]
      'OK'
    end
    klass.new
  end

  def native_call(id, name, namespace: 'computer')
    { type: 'tool_use', id:, name:, toolset_name: namespace, input: {} }
  end

  def stub_turns(*turns)
    stub_request(:post, 'https://api.anthropic.com/v1/messages').to_return do |request|
      requests << JSON.parse(request.body)
      content = turns.shift or raise 'Unexpected request'
      { body: JSON.generate(id: 'msg_fixture', type: 'message', role: 'assistant', model:, content:,
                            stop_reason: content.first[:type] == 'tool_use' ? 'tool_use' : 'end_turn',
                            usage: { input_tokens: 10, output_tokens: 2 }),
        headers: { 'Content-Type' => 'application/json' } }
    end
  end

  def configured(record, *tools)
    record.with_tools(*tools).with_provider_tools({ type: 'computer_toolset_20260801' })
  end

  def done
    [{ type: 'text', text: 'Done' }]
  end

  it 'reloads native identity and approval before running a pending member in another instance' do
    screenshot = tool('screenshot', approval: true)
    stub_turns([native_call('native', 'screenshot')], done)
    configured(chat, screenshot).ask('Inspect')
    call_record = chat.messages.where(role: 'assistant').sole.ruby_llm_tool_calls.sole

    expect(call_record.namespace).to eq('computer')
    expect(call_record).to be_sequential
    expect(call_record.to_llm.namespace).to eq('computer')
    expect(executed).to be_empty
    Chat.find(chat.id).approve(call_record.to_llm)
    configured(Chat.find(chat.id), screenshot).complete

    expect(executed).to eq([%w[computer screenshot]])
    expect(requests.last['messages'][2]['content'].first).to include('toolset_name' => 'computer')
  end

  it 'remembers approvals only for the same namespace and member after a reload' do
    computer = tool('screenshot', approval: true)
    browser = tool('screenshot', namespace: 'browser', approval: true)
    stub_turns([native_call('first', 'screenshot')], done,
               [native_call('second', 'screenshot')], done,
               [native_call('third', 'screenshot', namespace: 'browser')])
    configured(chat, computer, browser).ask('Inspect')
    chat.approve(chat.pending_approvals.first, remember: true).complete
    restored = configured(Chat.find(chat.id), computer, browser)

    restored.ask('Inspect again')
    restored.ask('Inspect browser')

    expect(executed).to eq([%w[computer screenshot], %w[computer screenshot]])
    expect(restored.pending_approvals.map(&:namespace)).to eq(['browser'])
  end

  it 'does not execute a later action when another worker has claimed an earlier one' do
    stub_turns([native_call('first', 'left_click'), native_call('second', 'screenshot')])
    configured(chat, tool('left_click'), tool('screenshot')).ask_later('Inspect').generate
    calls = chat.messages.where(role: 'assistant').sole.ruby_llm_tool_calls.order(:id)
    calls.first.update!(claimed_until: 10.minutes.from_now)

    configured(Chat.find(chat.id), tool('left_click'), tool('screenshot')).run_tools

    expect(executed).to be_empty
    expect(calls.last.reload.result).to be_nil
    expect(calls.last.claimed_until).to be_nil
  end

  it 'keeps a failed sequence stopped when its saved history is loaded elsewhere' do
    stub_turns([native_call('first', 'left_click'), native_call('second', 'screenshot')], done)
    reply = configured(chat, tool('left_click'), tool('screenshot')).ask_later('Inspect').generate
    first = reply.tool_calls.values.first
    chat.add_message(role: :tool, content: JSON.generate(error: 'Click failed'), tool_call_id: first.id)

    configured(Chat.find(chat.id), tool('left_click'), tool('screenshot')).complete

    expect(executed).to be_empty
    expect(requests.last['messages'][2]['content'].last).to include('is_error' => true, 'toolset_name' => 'computer')
  end

  it 'reloads and resumes a native task without selecting a same-name ordinary executor' do
    task_class = Class.new(RubyLLM::Task)
    calls = executed
    native = tool('screenshot')
    native.define_singleton_method(:execute) do
      RubyLLM::Task.new(status: :input_required, data: { run_id: 7 })
    end
    native.define_singleton_method(:task) do |state, tool_call:|
      task_class.load(state, tool_call:)
    end
    native.define_singleton_method(:resume) do |task, **|
      calls << task.data
      'Screenshot ready'
    end
    ordinary = tool('screenshot', namespace: nil)
    ordinary.define_singleton_method(:task) { |*| raise 'Wrong task executor' }
    stub_turns([native_call('native', 'screenshot')], done)
    configured(chat, native, ordinary).ask('Inspect')

    restored = configured(Chat.find(chat.id), native, ordinary)
    task = restored.pending_tasks.sole

    expect(task).to be_an_instance_of(task_class)
    expect(task.tool_call.namespace).to eq('computer')
    expect(restored.complete.content).to eq('Done')
    expect(executed).to eq([{ 'run_id' => 7 }])
    expect(restored.messages.find_by(role: 'tool').content).to eq('Screenshot ready')
  end
end
