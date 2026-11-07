# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  let(:instrumenter) { CaptureInstrumenter.new }
  let(:model) { model_for(:openai, :temperature) }

  around do |example|
    previous = RubyLLM.config.instrumenter
    RubyLLM.config.instrumenter = instrumenter
    example.run
  ensure
    RubyLLM.config.instrumenter = previous
  end

  before do
    stub_const('InstrumentedLookup', Class.new(RubyLLM::Tool) do
      description 'Looks something up'
      def execute = 'found'
    end)
    stub_const('InstrumentedAgent', Class.new(described_class) do
      model model_for(:openai, :temperature)
      tools InstrumentedLookup
    end)
  end

  def reply(content = 'done')
    RubyLLM::Message.new(role: :assistant, content:, model:, input_tokens: 1, output_tokens: 1)
  end

  def tool_request
    call = RubyLLM::ToolCall.new(id: 'call_1', name: 'instrumented_lookup', arguments: {})
    RubyLLM::Message.new(role: :assistant, content: nil, model:, tool_calls: { call.id => call })
  end

  def stub_replies(chat, *replies)
    allow(chat.provider).to receive(:complete).and_return(*replies)
  end

  def events(name)
    instrumenter.events.filter_map { |event, payload| payload if event == name }
  end

  it 'wraps each turn of an agent in one agent event, however many moves it takes' do
    agent = InstrumentedAgent.new
    stub_replies(agent.chat, tool_request, reply, reply)

    agent.ask('Look it up')
    agent.ask('Thanks')

    expect(events('agent.ruby_llm').size).to eq(2)
    expect(events('agent.ruby_llm')).to all(include(agent_name: 'InstrumentedAgent', chat: agent.chat))
    expect(events('chat.ruby_llm').size).to eq(3)
    expect(events('chat.ruby_llm')).to all(include(agent_name: 'InstrumentedAgent'))
    expect(events('tool_call.ruby_llm')).to contain_exactly(include(agent_name: 'InstrumentedAgent'))
  end

  it 'finishes the agent event after the chat and tool events of its run' do
    agent = InstrumentedAgent.new
    stub_replies(agent.chat, tool_request, reply)

    agent.ask('Look it up')

    expect(instrumenter.events.map(&:first).grep(/\A(agent|chat|tool_call)\./))
      .to eq(%w[chat.ruby_llm tool_call.ruby_llm chat.ruby_llm agent.ruby_llm])
  end

  it 'opens one agent event for each operation called on its own' do
    chat = InstrumentedAgent.chat
    stub_replies(chat, tool_request, reply)

    chat.ask_later('Look it up')
    chat.generate
    chat.run_tools
    chat.step

    expect(events('agent.ruby_llm').size).to eq(3)
  end

  it 'opens a nested agent event for a subagent run inside a tool' do
    stub_const('InstrumentedSubagent', Class.new(described_class) { model model_for(:openai, :temperature) })
    subagent = InstrumentedSubagent.new
    stub_replies(subagent.chat, reply('sub'))
    stub_const('InstrumentedDelegate', Class.new(RubyLLM::Tool) do
      description 'Delegates'
      define_method(:execute) { subagent.ask('Help').content }
    end)
    agent = InstrumentedAgent.new
    agent.with_tools(InstrumentedDelegate)
    call = RubyLLM::ToolCall.new(id: 'call_2', name: 'instrumented_delegate', arguments: {})
    delegation = RubyLLM::Message.new(role: :assistant, content: nil, model:, tool_calls: { call.id => call })
    stub_replies(agent.chat, delegation, reply)

    agent.ask('Delegate it')

    expect(events('agent.ruby_llm').map { |payload| payload[:agent_name] })
      .to eq(%w[InstrumentedSubagent InstrumentedAgent])
    expect(events('tool_call.ruby_llm').first).to include(agent_name: 'InstrumentedAgent')
  end

  it 'carries the agent description when the agent has one' do
    InstrumentedAgent.description 'Looks things up'
    agent = InstrumentedAgent.new
    stub_replies(agent.chat, reply, reply)

    agent.ask('Hello')
    Class.new(described_class) { model model_for(:openai, :temperature) }.new.tap do |plain|
      stub_replies(plain.chat, reply)
      plain.ask('Hello')
    end

    first, second = events('agent.ruby_llm')
    expect(first).to include(agent_description: 'Looks things up')
    expect(second).not_to have_key(:agent_description)
  end

  it 'carries the workflow fields' do
    agent = InstrumentedAgent.new
    stub_replies(agent.chat, reply)

    RubyLLM.workflow('support') { agent.ask('Hello') }

    expect(events('agent.ruby_llm').first).to include(workflow_name: 'support')
  end

  it 'reports an agent without a class name as an agent event without a name' do
    agent = Class.new(described_class) { model model_for(:openai, :temperature) }.new
    stub_replies(agent.chat, reply)

    agent.ask('Hello')

    expect(events('agent.ruby_llm')).to contain_exactly(include(agent_name: nil))
    expect(events('chat.ruby_llm').first).not_to have_key(:agent_name)
  end

  it 'leaves chats without an agent out of agent events' do
    chat = RubyLLM.chat(model:)
    stub_replies(chat, reply)

    chat.ask('Hello')

    expect(events('agent.ruby_llm')).to be_empty
    expect(events('chat.ruby_llm').first).not_to have_key(:agent_name)
  end
end
