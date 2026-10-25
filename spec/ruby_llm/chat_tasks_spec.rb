# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:approvals) { {} }
  let(:resumes) { [] }

  let(:sub_agent_tool) do
    decided = approvals
    calls = resumes
    Class.new(RubyLLM::Tool) do
      define_method(:name) { 'sub_agent' }
      define_method(:execute) do |job:|
        RubyLLM::Task.new(status: :input_required, status_message: "Waiting for approval to #{job}",
                          data: { run_id: 7 })
      end
      define_method(:resume) do |task, **arguments|
        calls << [task.data, arguments]
        decided.key?(task.data['run_id']) ? "Ran #{arguments[:job]}" : task
      end
    end
  end

  def tool_call_message(name = 'sub_agent', arguments = { 'job' => 'deploy' })
    RubyLLM::Message.new(role: :assistant, content: '',
                         tool_calls: { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name:, arguments:) })
  end

  def stubbed_chat(*tools)
    chat = RubyLLM.chat.with_tools(*tools)
    allow(chat.provider).to receive(:complete)
      .and_return(tool_call_message, RubyLLM::Message.new(role: :assistant, content: 'Done'))
    chat
  end

  it 'pauses a tool call that returns a task, without waiting for it' do
    chat = stubbed_chat(sub_agent_tool)

    chat.ask('Deploy')

    expect(chat).to be_waiting
    expect(chat).to be_awaiting_tasks
    expect(chat).not_to be_complete
    expect(chat.pending_tasks.first).to be_input_required
    expect(chat.pending_tasks.first).to have_attributes(
      status: :input_required, status_message: 'Waiting for approval to deploy', data: { 'run_id' => 7 },
      tool_call: have_attributes(name: 'sub_agent')
    )
  end

  it 'resumes the call with its task and arguments every time it completes, until it has a result' do
    chat = stubbed_chat(sub_agent_tool)
    chat.ask('Deploy')

    chat.complete
    expect(chat).to be_awaiting_tasks

    approvals[7] = true
    expect(chat.complete.content).to eq('Done')
    expect(chat).not_to be_awaiting_tasks
    expect(chat.messages.find(&:tool_result?).content).to eq('Ran deploy')
    expect(resumes).to eq([[{ 'run_id' => 7 }, { job: 'deploy' }]] * 2)
  end

  it 'rebuilds the task with the tool and cancels it when the chat is cancelled' do
    cancelled = []
    task_class = Class.new(RubyLLM::Task) do
      define_method(:cancel) { cancelled << data['run_id'] and self }
    end
    tool = Class.new(sub_agent_tool) do
      define_method(:task) { |state, tool_call: nil| task_class.load(state, tool_call:) }
    end
    chat = stubbed_chat(tool)
    chat.ask('Deploy')

    expect(chat.pending_tasks.first).to be_a(task_class)
    chat.cancel
    expect { chat.complete }.to raise_error(RubyLLM::CancelledError)

    expect(cancelled).to eq([7])
    expect(chat).not_to be_waiting
  end

  it 'clears a call whose task fails to cancel, and logs its tool call' do
    task_class = Class.new(RubyLLM::Task) do
      define_method(:cancel) { raise RubyLLM::Error, 'gone' }
    end
    tool = Class.new(sub_agent_tool) do
      define_method(:task) { |state, tool_call: nil| task_class.load(state, tool_call:) }
    end
    chat = stubbed_chat(tool)
    chat.ask('Deploy')
    logged = []
    allow(RubyLLM.logger).to receive(:debug) { |&message| logged << message&.call }
    tool_call_id = chat.messages.find(&:tool_call?).tool_calls.each_key.first
    chat.cancel
    expect { chat.complete }.to raise_error(RubyLLM::CancelledError)

    expect(chat).not_to be_waiting
    expect(logged).to include("RubyLLM could not cancel the task of tool call #{tool_call_id}: gone")
  end

  it 'raises for a tool that returns a task without implementing resume' do
    tool = Class.new(RubyLLM::Tool) do
      define_method(:name) { 'sub_agent' }
      define_method(:execute) { |job:| RubyLLM::Task.new(data: { job: }) }
    end
    chat = stubbed_chat(tool)
    chat.ask('Deploy')

    expect { chat.complete }.to raise_error(NotImplementedError, /must implement #resume/)
  end
end
