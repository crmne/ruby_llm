# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:executions) { [] }
  let(:refund) do
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

  def calls(*ids, name: 'refund', remote: false)
    tool_calls = ids.to_h { |id| [id, RubyLLM::ToolCall.new(id:, name:, arguments: {}, remote:)] }
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls:)
  end

  def stubbed_chat(*responses)
    chat = RubyLLM.chat.with_tools(refund)
    allow(chat.provider).to receive(:complete)
      .and_return(*responses, RubyLLM::Message.new(role: :assistant, content: 'All done'))
    chat
  end

  it 'runs later calls to a tool approved with remember: true' do
    chat = stubbed_chat(calls('call_1'), calls('call_2'))
    chat.ask('Go')

    chat.approve(chat.pending_approvals.first, remember: true).complete

    expect(executions).to eq(%i[refund refund])
  end

  it 'remembers by tool call id and refuses an unknown one' do
    chat = stubbed_chat(calls('call_1'), calls('call_2'))
    chat.ask('Go')

    chat.approve('call_1', remember: true).complete

    expect(executions).to eq(%i[refund refund])
    expect { chat.approve('missing', remember: true) }.to raise_error(ArgumentError, /Unknown tool call/)
  end

  it 'asks again for later calls approved without remember' do
    chat = stubbed_chat(calls('call_1'), calls('call_2'))
    chat.ask('Go')

    chat.approve('call_1').complete

    expect(executions).to eq([:refund])
    expect(chat.pending_approvals.map(&:id)).to eq(['call_2'])
  end

  it 'remembers remote tools by name' do
    chat = RubyLLM.chat
    chat.add_message(calls('call_1', name: 'deploy', remote: true))
    chat.approve('call_1', remember: true)
    chat.add_message(calls('call_2', name: 'deploy', remote: true))

    expect(chat.pending_approvals).to be_empty
  end
end
