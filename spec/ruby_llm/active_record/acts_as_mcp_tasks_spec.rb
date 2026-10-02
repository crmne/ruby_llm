# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ActsAs do
  include_context 'with configured RubyLLM'

  let(:call_id) { "call_#{SecureRandom.hex(6)}" }
  let(:reports) do
    command = [RbConfig.ruby, File.expand_path('../../fixtures/mcp/server.rb', __dir__)]
    Class.new(RubyLLM::MCP) do
      command(*command)
      extension :tasks
    end.new
  end

  after { reports.close }

  def paused_chat(tool = 'report')
    chat = Chat.create!(model: 'gpt-4.1-nano').with_mcp(reports)
    chat.add_message(
      RubyLLM::Message.new(role: :assistant, content: '',
                           tool_calls: { call_id => RubyLLM::ToolCall.new(id: call_id, name: tool, arguments: {}) })
    )
    chat.complete
    chat
  end

  def tool_call_record
    RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call_id)
  end

  it 'persists the task a tool call became' do
    chat = paused_chat

    expect(chat).to be_awaiting_tasks
    expect(tool_call_record.mcp_state['task'])
      .to include('taskId' => 'task-1', 'pollIntervalMs' => 10, 'ttlMs' => 60_000)
    expect(Chat.find(chat.id).with_mcp(reports).pending_tasks.first).to have_attributes(id: 'task-1', status: :working)
  end

  it 'checks on the task from another process and resumes once it finishes' do
    chat = paused_chat

    Chat.find(chat.id).with_mcp(reports).complete
    resumed = Chat.find(chat.id).with_mcp(reports)
    expect(resumed.pending_tasks.first.status_message).to eq('Rendering')

    allow(resumed.to_llm.provider).to receive(:complete).and_return(
      RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)
    )
    resumed.complete

    expect(resumed.messages_association.find_by(role: 'tool').content).to eq('Report ready')
    expect(tool_call_record.mcp_state).to be_nil
    expect(resumed).not_to be_awaiting_tasks
  end

  it 'cancels the task when another process cancels the chat' do
    chat = paused_chat('endless_report')
    Chat.find(chat.id).cancel

    expect { Chat.find(chat.id).with_mcp(reports).complete }.to raise_error(RubyLLM::CancelledError)
    expect(reports.send(:client).request('spec/tasks')['cancelled']).to eq(['task-1'])
  end
end
