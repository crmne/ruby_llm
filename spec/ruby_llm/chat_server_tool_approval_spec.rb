# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:chat) { RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :responses) }
  let(:remote_call) { RubyLLM::ToolCall.new(id: 'approval_1', name: 'search', arguments: { 'query' => 'Ruby' }, remote: true) }
  let(:final_message) { RubyLLM::Message.new(role: :assistant, content: 'Ruby documentation') }
  let(:executions) { [] }
  let(:local_tool) do
    calls = executions
    Class.new(RubyLLM::Tool) do
      define_method(:name) { 'search' }
      define_method(:execute) do
        calls << :local
        'local result'
      end
    end
  end

  def provider
    chat.instance_variable_get(:@provider)
  end

  def stage(*calls)
    response = RubyLLM::Message.new(role: :assistant, content: nil, tool_calls: calls.to_h { |call| [call.id, call] })
    allow(provider).to receive(:complete).and_return(response, final_message)
    chat.ask('Look up Ruby')
  end

  it 'parks without trying to execute a remote approval request locally' do
    chat.with_tools(local_tool)
    stage(remote_call)

    expect(chat).to be_awaiting_approval
    expect(chat.pending_approvals).to eq([remote_call])
    expect(executions).to be_empty
    expect(provider).to have_received(:complete).once
  end

  [true, false].each do |approved|
    it "records a server #{approved ? 'approval' : 'denial'} exactly once without executing a same-name local tool" do
      chat.with_tools(local_tool)
      stage(remote_call)
      approved ? chat.approve(remote_call) : chat.deny(remote_call)

      chat.run_tools.run_tools
      decisions = chat.messages.select(&:tool_result?)
      expect(decisions.size).to eq(1)
      expect(decisions.first.raw_content).to eq([
                                                  { type: 'mcp_approval_response', approval_request_id: 'approval_1',
                                                    approve: approved }
                                                ])
      expect(executions).to be_empty
      expect(chat.complete).to equal(final_message)
    end
  end

  it 'runs local calls in a mixed round before parking for the server decision' do
    chat.with_tools(local_tool)
    local_call = RubyLLM::ToolCall.new(id: 'local_1', name: 'search')
    stage(remote_call, local_call)

    expect(executions).to eq([:local])
    expect(chat).to be_awaiting_approval
    chat.approve(remote_call)
    chat.complete

    expect(executions).to eq([:local])
    expect(chat.messages.select(&:tool_result?).map(&:tool_call_id)).to eq(%w[local_1 approval_1])
  end
end
