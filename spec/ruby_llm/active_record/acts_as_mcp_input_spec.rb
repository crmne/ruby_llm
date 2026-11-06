# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ActsAs do
  include_context 'with configured RubyLLM'

  let(:call_id) { "call_#{SecureRandom.hex(6)}" }
  let(:files) do
    command = [RbConfig.ruby, File.expand_path('../../fixtures/mcp/server.rb', __dir__)]
    Class.new(RubyLLM::MCP) { command(*command) }.new
  end

  after { files.close }

  def paused_chat
    chat = Chat.create!(model: model_for(:openai, :temperature)).with_mcp(files)
    chat.add_message(
      RubyLLM::Message.new(role: :assistant, content: '',
                           tool_calls: { call_id => RubyLLM::ToolCall.new(id: call_id, name: 'deploy', arguments: {}) })
    )
    chat.complete
    chat
  end

  def tool_call_record
    RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call_id)
  end

  it 'persists the input a paused tool call waits on' do
    chat = paused_chat

    expect(chat).to be_awaiting_input
    expect(tool_call_record.mcp_state).to include('request_state' => 'environment-state')
    expect(chat.pending_inputs.first.message).to eq('Which environment?')
  end

  it 'reads the persisted input on a copy of the underlying chat' do
    chat = paused_chat
    copy = chat.to_llm.dup

    expect(copy).to be_awaiting_input

    RubyLLM::ActiveRecord::ToolCall.where(tool_call_id: call_id).update_all(mcp_state: nil)

    expect(copy).not_to be_awaiting_input
  end

  it 'binds a copy of the record to its own tool call state' do
    chat = paused_chat

    copy = chat.dup
    state = copy.to_llm.instance_variable_get(:@tool_call_state)

    expect(state).not_to be(chat.to_llm.instance_variable_get(:@tool_call_state))
    expect(state.instance_variable_get(:@chat)).to be(copy)
  end

  it 'sees what another process recorded on the same chat after a reload' do
    chat = paused_chat
    RubyLLM::ActiveRecord::ToolCall.where(tool_call_id: call_id).update_all(mcp_state: nil)

    expect(chat.reload).not_to be_awaiting_input
  end

  it 'releases the claims of a call that pauses for input' do
    chat = paused_chat

    expect(tool_call_record.claimed_until).to be_nil
    expect(tool_call_record).not_to be_running
    expect(chat).not_to be_running
  end

  it 'clears a leftover cancel when the user answers' do
    chat = paused_chat
    Chat.where(id: chat.id).update_all(cancelled: true)
    answering = Chat.find(chat.id).with_mcp(files)

    answering.answer(answering.pending_inputs.first, environment: 'staging')

    expect(Chat.find(chat.id)).not_to be_cancelled
  end

  it 'keeps a cancel when the input has nowhere to go' do
    chat = paused_chat
    Chat.where(id: chat.id).update_all(cancelled: true)
    state = Chat.find(chat.id).with_mcp(files).to_llm.instance_variable_get(:@tool_call_state)

    state.record_input(RubyLLM::ToolCall.new(id: 'missing', name: 'deploy', arguments: {}), { 'requests' => [] })

    expect(Chat.find(chat.id)).to be_cancelled
  end

  it 'keeps a cancel when an answer changes nothing' do
    chat = paused_chat
    Chat.where(id: chat.id).update_all(cancelled: true)
    state = Chat.find(chat.id).with_mcp(files).to_llm.instance_variable_get(:@tool_call_state)
    tool_call = RubyLLM::ToolCall.new(id: call_id, name: 'deploy', arguments: {})

    state.record_input(tool_call, tool_call_record.mcp_state)

    expect(Chat.find(chat.id)).to be_cancelled
  end

  it 'resumes from another process after the user answers' do
    chat = paused_chat
    answering = Chat.find(chat.id).with_mcp(files)
    answering.answer(answering.pending_inputs.first, environment: 'staging')

    resumed = Chat.find(chat.id).with_mcp(files)
    allow(resumed.to_llm.provider).to receive(:complete).and_return(
      RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)
    )
    resumed.complete

    expect(resumed.messages_association.find_by(role: 'tool').content).to eq('Deployed to staging')
    expect(tool_call_record.mcp_state).to be_nil
    expect(resumed).not_to be_awaiting_input
  end
end
