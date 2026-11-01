# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:default_sandbox) { FakeSandbox.new }
  let(:online_sandbox) do
    stub_const('OnlineSandbox', Class.new(FakeSandbox))
    OnlineSandbox.new(network: true)
  end
  let(:executions) { [] }
  let(:refund_tool) do
    runs = executions
    Class.new(RubyLLM::Tool) do
      requires_approval
      define_singleton_method(:tool_name) { 'refund' }
      define_method(:execute) do
        runs << :refund
        'refunded'
      end
    end
  end

  around do |example|
    before = RubyLLM.config.sandbox
    RubyLLM.config.sandbox = default_sandbox
    example.run
  ensure
    RubyLLM.config.sandbox = before
  end

  def park(chat, call)
    chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }))
    call
  end

  def process(chat)
    Chat.find(chat.id).with_tools(refund_tool).with_code_execution(escalate_to: [online_sandbox]).tap do |record|
      allow(record.to_llm.provider).to receive(:complete)
        .and_return(RubyLLM::Message.new(role: :assistant, content: 'Done'))
    end
  end

  def call(name, arguments = {})
    RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name:, arguments:)
  end

  describe 'pending approvals with the query cache enabled' do
    %w[approved denied result].each do |decision|
      it "stops listing a call after another connection records #{decision}" do
        chat = Chat.create!(model: model_for(:openai)).with_tools(refund_tool)
        pending = park(chat, call('refund'))
        row = RubyLLM::ActiveRecord::ToolCall.find_by!(tool_call_id: pending.id)
        result = chat.messages.create!(role: 'tool', content: 'done') if decision == 'result'
        attributes = result ? { result_id: result.id } : { approval: decision }

        RubyLLM::ActiveRecord::ToolCall.cache do
          expect(chat.pending_approvals.map(&:tool_call_id)).to eq([pending.id])
          expect(chat.pending_approvals.where(name: 'refund').limit(1).count).to eq(1)

          Thread.new do
            RubyLLM::ActiveRecord::ToolCall.connection_pool.with_connection do
              RubyLLM::ActiveRecord::ToolCall.where(id: row.id).update_all(attributes)
            end
          end.value

          expect(chat.pending_approvals.map(&:tool_call_id)).to eq([])
          expect(chat.pending_approvals.where(name: 'refund').limit(1).count).to eq(0)
        end
      end
    end
  end

  it 'remembers an approval on the tool call, for every process' do
    chat = process(Chat.create!(model: model_for(:openai)))
    first = park(chat, call('refund'))

    chat.approve(first.id, remember: true)

    expect(RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: first.id).approval).to eq('remembered')
    later = process(chat)
    park(later, call('refund'))
    expect(later.pending_approvals).to be_empty
  end

  it 'remembers approvals in a database that has not added tool call namespaces' do
    connection = RubyLLM::ActiveRecord::ToolCall.connection
    connection.remove_column(:ruby_llm_tool_calls, :namespace)
    RubyLLM::ActiveRecord::ToolCall.reset_column_information
    chat = process(Chat.create!(model: model_for(:openai)))
    first = park(chat, call('refund'))
    expect(Chat.find(chat.id).pending_approvals.map(&:tool_call_id)).to eq([first.id])

    chat.approve(first.id, remember: true)

    later = process(chat)
    park(later, call('refund'))
    expect(later.pending_approvals).to be_empty
  ensure
    connection.add_column(:ruby_llm_tool_calls, :namespace, :string)
    RubyLLM::ActiveRecord::ToolCall.reset_column_information
  end

  it 'stops listing parallel calls to a tool once another process remembers it' do
    chat = process(Chat.create!(model: model_for(:openai)))
    first = call('refund')
    second = call('refund')
    tool_calls = { first.id => first, second.id => second }
    chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls:))
    expect(Chat.find(chat.id).pending_approvals.map(&:tool_call_id)).to eq([first.id, second.id])

    Chat.find(chat.id).approve(first.id, remember: true)

    expect(Chat.find(chat.id).pending_approvals).to be_empty
  end

  it 'approves an escalated run in one process and runs it once in another' do
    chat = process(Chat.create!(model: model_for(:openai)))
    escalated = park(chat, call('run_code', 'language' => 'shell', 'code' => 'curl example.com',
                                            'sandbox' => 'online', 'reason' => 'Fetch the page'))
    expect(chat.pending_approvals.map(&:tool_call_id)).to eq([escalated.id])

    expect { Chat.find(chat.id).approve(escalated.id, remember: true) }
      .to raise_error(ArgumentError, /cannot be remembered/)
    expect(RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: escalated.id).approval).to eq('pending')

    Chat.find(chat.id).approve(escalated.id)
    process(chat).complete

    expect(online_sandbox.code_runs.size).to eq(1)
    expect(default_sandbox.code_runs).to be_empty
    later = process(chat)
    park(later, call('run_code', 'language' => 'shell', 'code' => 'curl example.com', 'sandbox' => 'online'))
    expect(later.pending_approvals.size).to eq(1)
  end
end
