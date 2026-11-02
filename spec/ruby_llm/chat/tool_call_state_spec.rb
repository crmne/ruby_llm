# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat::ToolCallState do
  include_context 'with configured RubyLLM'

  let(:state) { described_class.new }
  let(:tool_call) { RubyLLM::ToolCall.new(id: 'call_1', name: 'deploy', arguments: {}) }

  it 'reads back the input recorded for a tool call' do
    state.record_input(tool_call, 'requests' => [])

    expect(state.input(tool_call)).to eq('requests' => [])
  end

  it 'gives a copy its own inputs' do
    state.record_input(tool_call, 'requests' => [])
    copy = state.dup

    copy.record_input(tool_call, nil)

    expect(state.input(tool_call)).to eq('requests' => [])
    expect(copy.input(tool_call)).to be_nil
  end

  it 'reads back a decision and tells denials apart from undecided calls' do
    expect(state.decision(tool_call)).to be_nil
    expect(state).not_to be_denied(tool_call)

    state.record_decision(tool_call.id, false)

    expect(state.decision(tool_call)).to be(false)
    expect(state).to be_denied(tool_call)
  end

  it 'remembers a tool by namespace and name' do
    other = RubyLLM::ToolCall.new(id: 'call_2', name: 'deploy', arguments: {}, namespace: 'github')

    state.remember([nil, 'deploy'])

    expect(state).to be_remembered(tool_call)
    expect(state).not_to be_remembered(other)
  end

  it 'spends an escalation once per call' do
    expect { state.spend_escalation(tool_call) }.to change { state.escalation_spent?(tool_call) }.from(false).to(true)
  end

  it 'gives a copy its own approvals' do
    state.record_decision(tool_call.id, true)
    state.remember(%w[github deploy])
    state.spend_escalation(tool_call)
    other = RubyLLM::ToolCall.new(id: 'call_2', name: 'run', arguments: {})
    copy = state.dup

    copy.record_decision(tool_call.id, false)
    copy.remember([nil, 'deploy'])
    copy.spend_escalation(other)

    expect(state.decision(tool_call)).to be(true)
    expect(state).not_to be_remembered(tool_call)
    expect(state).not_to be_escalation_spent(other)
    expect(copy).to be_escalation_spent(tool_call)
  end

  it 'keeps a paused call paused on a copy of the chat, independently of the original' do
    chat = RubyLLM.chat(model: RubyLLM.config.default_model)
    chat.add_message(role: :assistant, content: '', tool_calls: { 'call_1' => tool_call })
    chat.tool_call_state = state
    state.record_input(tool_call, 'requests' => [{ 'key' => 'env', 'params' => {}, 'response' => nil }])

    branch = chat.dup
    branch.__send__(:record_tool_call_input, tool_call, nil)

    expect(chat).to be_awaiting_input
    expect(branch).not_to be_awaiting_input
  end
end
