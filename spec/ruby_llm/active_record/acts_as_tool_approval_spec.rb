# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ActsAs do
  include_context 'with configured RubyLLM'

  let(:call_id) { "call_#{SecureRandom.hex(6)}" }

  let(:approval_tool) do
    Class.new(RubyLLM::Tool) do
      requires_approval

      define_method(:name) { 'dangerous' }
      define_method(:execute) { 'done' }
    end
  end

  def parked_chat
    chat = Chat.create!(model: 'gpt-4.1-nano')
    chat.with_tools(approval_tool)
    chat.add_message(
      RubyLLM::Message.new(
        role: :assistant,
        content: '',
        tool_calls: { call_id => RubyLLM::ToolCall.new(id: call_id, name: 'dangerous', arguments: {}) }
      )
    )
    chat
  end

  it 'returns the persisted tool call records awaiting a decision' do
    chat = parked_chat

    records = chat.pending_approvals
    expect(records.map(&:tool_call_id)).to eq([call_id])
    expect(records.first).to be_a(RubyLLM::ActiveRecord::ToolCall)
    expect(chat).to be_awaiting_approval
  end

  it 'persists an approval recorded from a pending record' do
    chat = parked_chat

    chat.approve(chat.pending_approvals.first)

    expect(chat.pending_approvals).to be_empty
    expect(chat).not_to be_awaiting_approval
    expect(RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call_id).approval).to eq('approved')
  end

  it 'reads a decision persisted by another process' do
    chat = parked_chat
    RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call_id).update!(approval: 'denied')

    reloaded = Chat.find(chat.id)
    reloaded.with_tools(approval_tool)

    expect(reloaded).not_to be_awaiting_approval
    expect(reloaded.pending_approvals).to be_empty
  end

  it 'refuses to persist a new question while the round is parked' do
    chat = parked_chat

    expect { chat.ask_later('Write an essay instead') }.to raise_error(RubyLLM::PendingToolCallsError)
    expect(chat.messages_association.where(role: 'user')).to be_empty
  end
end
