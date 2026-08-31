# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:executions) { [] }

  let(:dangerous_tool) do
    runs = executions
    Class.new(RubyLLM::Tool) do
      requires_approval

      define_method(:name) { 'dangerous' }
      define_method(:execute) do
        runs << :dangerous
        'done'
      end
    end
  end

  let(:harmless_tool) do
    runs = executions
    Class.new(RubyLLM::Tool) do
      define_method(:name) { 'harmless' }
      define_method(:execute) do
        runs << :harmless
        'fine'
      end
    end
  end

  def tool_call_message(calls)
    tool_calls = calls.to_h do |id, name|
      [id, RubyLLM::ToolCall.new(id: id, name: name, arguments: {})]
    end
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls: tool_calls)
  end

  def final_message
    RubyLLM::Message.new(role: :assistant, content: 'All done')
  end

  def stubbed_chat(*responses, tools:)
    chat = RubyLLM.chat.with_tools(*tools)
    provider = chat.instance_variable_get(:@provider)
    allow(provider).to receive(:complete).and_return(*responses)
    chat
  end

  it 'parks the loop until a decision is recorded' do
    chat = stubbed_chat(tool_call_message('call_1' => 'dangerous'), final_message, tools: [dangerous_tool])

    response = chat.ask('Do the thing')

    expect(chat).to be_awaiting_approval
    expect(chat).not_to be_complete
    expect(executions).to be_empty
    expect(response.tool_calls.keys).to eq(['call_1'])
  end

  it 'resumes and executes after approve' do
    chat = stubbed_chat(tool_call_message('call_1' => 'dangerous'), final_message, tools: [dangerous_tool])
    chat.ask('Do the thing')

    chat.approve('call_1')
    response = chat.complete

    expect(executions).to eq([:dangerous])
    expect(response.content).to eq('All done')
    expect(chat).to be_complete
    expect(chat).not_to be_awaiting_approval
  end

  it 'accepts a ToolCall for approve' do
    chat = stubbed_chat(tool_call_message('call_1' => 'dangerous'), final_message, tools: [dangerous_tool])
    response = chat.ask('Do the thing')

    chat.approve(response.tool_calls.values.first)
    chat.complete

    expect(executions).to eq([:dangerous])
  end

  it 'appends a structured denial result after deny' do
    chat = stubbed_chat(tool_call_message('call_1' => 'dangerous'), final_message, tools: [dangerous_tool])
    chat.ask('Do the thing')

    chat.deny('call_1')
    response = chat.complete

    expect(executions).to be_empty
    denial = chat.messages.find(&:tool_result?)
    expect(denial.content).to include('denied the dangerous tool call')
    expect(denial.tool_call_id).to eq('call_1')
    expect(response.content).to eq('All done')
  end

  it 'does not carry bang aliases' do
    chat = RubyLLM.chat

    expect(chat).not_to respond_to(:approve!, :deny!)
  end

  it 'executes immediately when the resolver returns true' do
    approving_tool = Class.new(dangerous_tool) do
      requires_approval { |_tool_call| true }
    end
    chat = stubbed_chat(tool_call_message('call_1' => 'dangerous'), final_message, tools: [approving_tool])

    response = chat.ask('Do the thing')

    expect(executions).to eq([:dangerous])
    expect(response.content).to eq('All done')
  end

  it 'denies without executing when the resolver returns false' do
    denying_tool = Class.new(dangerous_tool) do
      requires_approval { |_tool_call| false }
    end
    chat = stubbed_chat(tool_call_message('call_1' => 'dangerous'), final_message, tools: [denying_tool])

    response = chat.ask('Do the thing')

    expect(executions).to be_empty
    expect(chat.messages.find(&:tool_result?).content).to include('denied')
    expect(response.content).to eq('All done')
  end

  it 'consults the resolver lazily, never at definition or registration' do
    resolver_calls = []
    lazy_tool = Class.new(dangerous_tool) do
      requires_approval do |tool_call|
        resolver_calls << tool_call.id
        nil
      end
    end

    chat = stubbed_chat(tool_call_message('call_1' => 'dangerous'), final_message, tools: [lazy_tool])
    expect(resolver_calls).to be_empty

    chat.ask('Do the thing')

    expect(resolver_calls.uniq).to eq(['call_1'])
    expect(chat).to be_awaiting_approval
    expect(executions).to be_empty
  end

  it 'refuses a new question while the round is parked' do
    chat = stubbed_chat(tool_call_message('call_1' => 'dangerous'), final_message, tools: [dangerous_tool])
    chat.ask('Do the thing')

    expect { chat.ask('Write an essay instead') }.to raise_error(RubyLLM::PendingToolCallsError, /dangerous/)
    expect(chat.messages.count { |message| message.role == :user }).to eq(1)
  end

  it 'refuses a new question while any tool call is unanswered, approval or not' do
    chat = stubbed_chat(tool_call_message('call_1' => 'harmless'), tools: [harmless_tool])
    chat.ask_later('Do it')
    chat.generate

    expect { chat.ask_later('Another thing') }.to raise_error(RubyLLM::PendingToolCallsError, /harmless/)
  end

  it 'lists the pending approvals as ToolCall objects' do
    chat = stubbed_chat(tool_call_message('call_1' => 'dangerous'), final_message, tools: [dangerous_tool])
    chat.ask('Do the thing')

    expect(chat.pending_approvals.map(&:id)).to eq(['call_1'])
    expect(chat.pending_approvals.first.name).to eq('dangerous')

    chat.approve(chat.pending_approvals.first)
    chat.complete

    expect(chat.pending_approvals).to be_empty
  end

  it 'shows what the chat is waiting for in inspect' do
    chat = stubbed_chat(tool_call_message('call_1' => 'dangerous'), final_message, tools: [dangerous_tool])
    chat.ask('Do the thing')

    expect(chat.inspect).to include('awaiting_approval: ["dangerous"]')

    chat.approve('call_1')
    chat.complete

    expect(chat.inspect).not_to include('awaiting_approval')
  end

  it 'runs tools that need no approval and parks only the one that does' do
    chat = stubbed_chat(
      tool_call_message('call_a' => 'harmless', 'call_b' => 'dangerous'),
      final_message,
      tools: [harmless_tool, dangerous_tool]
    )

    chat.ask('Do both things')

    expect(executions).to eq([:harmless])
    expect(chat).to be_awaiting_approval

    chat.approve('call_b')
    response = chat.complete

    expect(executions).to eq(%i[harmless dangerous])
    expect(response.content).to eq('All done')
  end
end
