# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ActsAs do
  include_context 'with configured RubyLLM'

  let(:call_id) { "call_#{SecureRandom.hex(6)}" }
  let(:approved) { [] }

  let(:sub_agent_tool) do
    decided = approved
    Class.new(RubyLLM::Tool) do
      define_method(:name) { 'sub_agent' }
      define_method(:execute) { |job:| RubyLLM::Task.new(status: :input_required, data: { 'job' => job }) }
      define_method(:resume) { |task, **| decided.any? ? "Ran #{task.data['job']}" : task }
    end
  end

  def paused_chat
    chat = Chat.create!(model: 'gpt-4.1-nano').with_tools(sub_agent_tool)
    chat.add_message(
      RubyLLM::Message.new(role: :assistant, content: '',
                           tool_calls: { call_id => RubyLLM::ToolCall.new(id: call_id, name: 'sub_agent',
                                                                          arguments: { 'job' => 'deploy' }) })
    )
    chat.complete
    chat
  end

  def tool_call_record
    RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call_id)
  end

  it 'persists the task a tool call returned' do
    chat = paused_chat

    expect(chat).to be_awaiting_tasks
    expect(tool_call_record.mcp_state)
      .to eq('task' => { 'status' => 'input_required', 'data' => { 'job' => 'deploy' } })
    expect(tool_call_record).to be_paused
    expect(Chat.find(chat.id).with_tools(sub_agent_tool).pending_tasks.first)
      .to have_attributes(status: :input_required, data: { 'job' => 'deploy' })
  end

  it 'releases the claim of a call that waits on a task' do
    chat = paused_chat

    expect(tool_call_record.claimed_until).to be_nil
    expect(chat).not_to be_running
  end

  it 'resumes the call from another process' do
    chat = paused_chat
    approved << true

    resumed = Chat.find(chat.id).with_tools(sub_agent_tool)
    allow(resumed.to_llm.provider).to receive(:complete).and_return(
      RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)
    )
    resumed.complete

    expect(resumed.messages_association.find_by(role: 'tool').content).to eq('Ran deploy')
    expect(tool_call_record.mcp_state).to be_nil
    expect(resumed).not_to be_awaiting_tasks
  end
end
