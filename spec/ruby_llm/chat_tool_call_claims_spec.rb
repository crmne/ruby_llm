# frozen_string_literal: true

require 'spec_helper'

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

  def approved_chat
    chat = RubyLLM.chat(model: model_for(:openai)).with_tools(charge_tool)
    chat.add_message(role: :user, content: 'Charge the card')
    tool_calls = { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'charge_card', arguments: {}) }
    chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls:))
    chat.approve('call_1')
    chat
  end

  def refusing_claims(chat)
    chat.tool_call_claimer = proc { |_leases, **| [] }
    chat
  end

  it 'waits on a call it could not claim while another process runs it' do
    chat = refusing_claims(approved_chat)
    chat.running_checker = proc { true }

    chat.run_tools

    expect(executions).to be_empty
    expect(chat).to be_waiting
  end

  it 'does not wait on a call it could not claim when nothing reports it running' do
    chat = refusing_claims(approved_chat)

    chat.run_tools

    expect(executions).to be_empty
    expect(chat).not_to be_waiting
  end

  it 'does not wait on a call it has not tried to claim, whatever reports it running' do
    chat = approved_chat
    chat.running_checker = proc { true }

    expect(chat).not_to be_waiting
  end

  it 'leases a denied call for the configured run time while it records the denial' do
    chat = approved_chat
    chat.deny('call_1')
    leases = []
    chat.tool_call_claimer = proc do |requested, **|
      leases << requested.transform_keys(&:id)
      requested.keys.map(&:id)
    end

    chat.run_tools

    expect(leases).to eq([{ 'call_1' => RubyLLM.config.max_run_time }])
    expect(executions).to be_empty
  end

  it "leases an approved call for its tool's own run time" do
    charge_tool.max_run_time 90
    chat = approved_chat
    leases = []
    chat.tool_call_claimer = proc do |requested, **|
      leases << requested.transform_keys(&:id)
      requested.keys.map(&:id)
    end

    chat.run_tools

    expect(leases).to eq([{ 'call_1' => 90 }])
  end

  it 'runs a call whose tool another process remembered as approved' do
    chat = RubyLLM.chat(model: model_for(:openai)).with_tools(charge_tool)
    chat.remembered_checker = proc { |call| call.name == 'charge_card' }
    chat.add_message(role: :user, content: 'Charge the card')
    tool_calls = { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'charge_card', arguments: {}) }
    chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls:))

    chat.run_tools

    expect(executions).to eq([:charged])
  end
end
