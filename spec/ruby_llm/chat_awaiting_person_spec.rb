# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:chat) { described_class.new(model: model_for(:anthropic)) }

  def tool_call(name)
    RubyLLM::Message.new(role: :assistant, content: '', input_tokens: 1, output_tokens: 1,
                         tool_calls: { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name:, arguments: {}) })
  end

  def task_tool(status)
    Class.new(RubyLLM::Tool) do
      description 'Starts slow work'
      define_method(:name) { "slow_#{status}" }
      define_method(:execute) { RubyLLM::Task.new(status:) }
      define_method(:resume) { |task, **| task }
    end
  end

  def approval_tool
    Class.new(RubyLLM::Tool) do
      description 'Deletes everything'
      requires_approval
      define_method(:name) { 'wipe' }
      define_method(:execute) { 'wiped' }
    end
  end

  def run(tool)
    allow(chat.provider).to receive(:complete).and_return(tool_call(tool.new.name))
    chat.with_tools(tool).ask('Go')
  end

  it 'is false for a chat that waits on nothing' do
    expect(chat).not_to be_awaiting_person
  end

  it 'is true while an approval waits for a decision' do
    run(approval_tool)

    expect(chat).to be_awaiting_person
  end

  it 'is true while a tool waits for an answer to its question' do
    question = Class.new(RubyLLM::Tool) do
      description 'Asks the team'
      define_method(:name) { 'ask_team' }
      define_method(:execute) { request_input('Which region?', region: { type: 'string' })[:region] }
    end
    run(question)

    expect(chat).to be_awaiting_input
    expect(chat).to be_awaiting_person
  end

  it 'is true while a task waits on a person, and false while one is only working' do
    run(task_tool(:input_required))

    expect(chat).to be_awaiting_person

    other = described_class.new(model: model_for(:anthropic))
    allow(other.provider).to receive(:complete).and_return(tool_call('slow_working'))
    other.with_tools(task_tool(:working)).ask('Go')

    expect(other).to be_awaiting_tasks
    expect(other).not_to be_awaiting_person
  end

  it 'is delegated by agents' do
    run(approval_tool)

    expect(Class.new(RubyLLM::Agent).new(chat:)).to be_awaiting_person
  end
end
