# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:executions) { [] }

  let(:charge_tool) do
    runs = executions
    Class.new(RubyLLM::Tool) do
      requires_approval

      define_method(:name) { 'charge_card' }
      define_method(:execute) do
        runs << :charged
        'charged'
      end
    end
  end

  def approved_chat(state = RubyLLM::Chat::ToolCallState.new)
    asking_chat(state).approve('call_1')
  end

  def asking_chat(state)
    chat = RubyLLM.chat(model: model_for(:openai)).with_tools(charge_tool)
    chat.tool_call_state = state
    chat.add_message(role: :user, content: 'Charge the card')
    tool_calls = { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'charge_card', arguments: {}) }
    chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls:))
    chat
  end

  def claims(running: false, &claimer)
    record = instance_double(Chat, find_tool_call: nil, persisted_tool_call_approval: nil,
                                   persisted_remembered_tool?: false, tool_call_running_elsewhere?: running,
                                   release_persisted_tool_calls: nil, persisted_tool_call_started: nil,
                                   persisted_decline_note: nil, record_persisted_decline_note: nil)
    allow(record).to receive(:claim_persisted_tool_calls, &claimer)
    RubyLLM::ActiveRecord::ChatToolCallState.new(record)
  end

  def refusing_claims(**)
    claims(**) { |_leases, **| [] }
  end

  def recording_leases(leases)
    claims do |requested, **|
      leases << requested.transform_keys(&:id)
      requested.keys.map(&:id)
    end
  end

  it 'waits on a call it could not claim while another process runs it' do
    chat = approved_chat(refusing_claims(running: true))

    chat.run_tools

    expect(executions).to be_empty
    expect(chat).to be_waiting
  end

  it 'does not wait on a call it could not claim when nothing reports it running' do
    chat = approved_chat(refusing_claims)

    chat.run_tools

    expect(executions).to be_empty
    expect(chat).not_to be_waiting
  end

  it 'does not wait on a call it has not tried to claim, whatever reports it running' do
    chat = approved_chat(refusing_claims(running: true))

    expect(chat).not_to be_waiting
  end

  it 'leases a denied call for the configured run time while it records the denial' do
    leases = []
    chat = asking_chat(recording_leases(leases))
    chat.decline('call_1')

    chat.run_tools

    expect(leases).to eq([{ 'call_1' => RubyLLM.config.max_run_time }])
    expect(executions).to be_empty
  end

  it "leases an approved call for its tool's own run time" do
    charge_tool.max_run_time 90
    leases = []
    chat = approved_chat(recording_leases(leases))

    chat.run_tools

    expect(leases).to eq([{ 'call_1' => 90 }])
  end

  it 'runs a call whose tool another process remembered as approved' do
    chat = RubyLLM.chat(model: model_for(:openai)).with_tools(charge_tool)
    state = RubyLLM::Chat::ToolCallState.new
    allow(state).to receive(:remembered?) { |call| call.name == 'charge_card' }
    chat.tool_call_state = state
    chat.add_message(role: :user, content: 'Charge the card')
    tool_calls = { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'charge_card', arguments: {}) }
    chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls:))

    chat.run_tools

    expect(executions).to eq([:charged])
  end
end
