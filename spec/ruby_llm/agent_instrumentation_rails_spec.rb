# frozen_string_literal: true

require 'rails_helper'

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
    stub_const('PersistedLookup', Class.new(RubyLLM::Tool) do
      description 'Looks something up'
      def execute = 'found'
    end)
    stub_const('PersistedAgent', Class.new(described_class) do
      chat_class Chat
      model model_for(:openai, :temperature)
      tools PersistedLookup
    end)
  end

  def reply(content = 'done')
    RubyLLM::Message.new(role: :assistant, content:, model:, input_tokens: 1, output_tokens: 1)
  end

  def tool_request
    call = RubyLLM::ToolCall.new(id: 'call_1', name: 'persisted_lookup', arguments: {})
    RubyLLM::Message.new(role: :assistant, content: nil, model:, tool_calls: { call.id => call })
  end

  def events(name)
    instrumenter.events.filter_map { |event, payload| payload if event == name }
  end

  it 'wraps each turn of a created record in one agent event with its chat id' do
    record = PersistedAgent.create!
    allow(record.to_llm.provider).to receive(:complete).and_return(tool_request, reply, reply)

    record.ask('Look it up')
    record.ask('Thanks')

    expect(events('agent.ruby_llm').size).to eq(2)
    expect(events('agent.ruby_llm'))
      .to all(include(agent_name: 'PersistedAgent', chat_id: record.id, chat: record.to_llm))
    expect(events('chat.ruby_llm')).to all(include(agent_name: 'PersistedAgent'))
    expect(events('tool_call.ruby_llm')).to contain_exactly(include(agent_name: 'PersistedAgent'))
  end

  it 'knows the agent of a found record and of the chat it wraps' do
    id = PersistedAgent.create.id
    record = PersistedAgent.find(id)
    allow(record.to_llm.provider).to receive(:complete).and_return(reply, reply)

    record.ask('Hello')
    record.to_llm.ask('Again')

    expect(events('agent.ruby_llm')).to contain_exactly(
      include(agent_name: 'PersistedAgent', chat_id: id),
      include(agent_name: 'PersistedAgent', chat_id: id)
    )
  end

  it 'keeps the turn a queued message continues in the same agent event' do
    record = PersistedAgent.create!
    allow(record.to_llm.provider).to receive(:complete).and_return(reply, reply)
    allow(record).to receive(:work_arrived_during_run?).and_return(true, false)

    record.ask('Hello')

    expect(events('agent.ruby_llm').size).to eq(1)
  end

  it 'opens one agent event for each record operation called on its own' do
    record = PersistedAgent.create!
    allow(record.to_llm.provider).to receive(:complete).and_return(tool_request, reply)

    record.ask_later('Look it up')
    record.generate
    record.run_tools
    record.step

    expect(events('agent.ruby_llm').size).to eq(3)
  end

  it 'leaves records without an agent out of agent events' do
    record = Chat.create!(model:)
    allow(record.to_llm.provider).to receive(:complete).and_return(reply)

    record.ask('Hello')

    expect(events('agent.ruby_llm')).to be_empty
  end
end
