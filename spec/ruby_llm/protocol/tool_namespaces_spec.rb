# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocol::ToolNamespaces do
  include_context 'with configured RubyLLM'

  def call(namespace)
    RubyLLM::ToolCall.new(name: 'screenshot', namespace:)
  end

  it 'runs every call on its own unless the protocol orders a namespace' do
    protocol = RubyLLM::Protocols::Responses.new(RubyLLM::Providers::OpenAI.new(RubyLLM.config))

    expect(protocol.skipped_tool_call_error(call('crm'))).to be_nil
    expect(protocol.skipped_tool_call_error(call(nil))).to be_nil
  end

  it "answers a skipped Anthropic toolset call with that toolset's halt text" do
    protocol = RubyLLM::Protocols::Anthropic.new(RubyLLM::Providers::Anthropic.new(RubyLLM.config))

    expect(protocol.skipped_tool_call_error(call('computer')))
      .to eq('Not executed: an earlier computer action in this turn failed.')
    expect(protocol.skipped_tool_call_error(call('browser')))
      .to eq('Not executed: an earlier action in this turn failed.')
    expect(protocol.skipped_tool_call_error(call(nil))).to be_nil
  end
end
