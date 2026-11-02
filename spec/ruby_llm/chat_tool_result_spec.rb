# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:runs) { [] }
  let(:requests) { [] }
  let(:tool) do
    calls = runs
    Class.new(RubyLLM::Tool) do
      description 'Returns a result the chat cannot send'
      define_method(:name) { 'mixed' }
      define_method(:execute) do
        calls << :run
        [RubyLLM::Attachment.new(StringIO.new('x'), filename: 'x.txt'), 42]
      end
    end
  end
  let(:chat) { described_class.new(model: model_for(:anthropic)).with_tools(tool.new) }

  before do
    answers = [
      RubyLLM::Message.new(role: :assistant, content: '', tool_calls: {
                             'call_1' => RubyLLM::ToolCall.new(id: 'call_1', provider_call_id: 'call_1',
                                                               name: 'mixed', arguments: {})
                           }),
      RubyLLM::Message.new(role: :assistant, content: 'Done')
    ]
    allow(chat.provider).to receive(:complete) do |messages, **|
      requests << messages.map(&:role)
      answers.shift
    end
  end

  it 'sends a result it cannot split back as an error and does not run the tool again' do
    expect(chat.ask('Go').content).to eq('Done')

    result = chat.messages.find(&:tool_result?)
    expect(JSON.parse(result.content)).to match('error' => a_string_including('Strings and RubyLLM::Attachments'))
    expect(runs.size).to eq(1)
    expect(requests.last).to eq(%i[user assistant tool])
  end
end
