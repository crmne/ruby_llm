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
    chat = Chat.create!(model: 'gpt-4.1-nano').with_mcp(files)
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
    expect(tool_call_record.pending_input).to include('request_state' => 'environment-state')
    expect(chat.pending_inputs.first.message).to eq('Which environment?')
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
    expect(tool_call_record.pending_input).to be_nil
    expect(resumed).not_to be_awaiting_input
  end
end
