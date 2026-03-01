# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Message do
  describe '#content' do
    it 'normalizes nil content to empty string for assistant tool-call messages' do
      tool_call = RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: {})
      message = described_class.new(role: :assistant, content: nil, tool_calls: { 'call_1' => tool_call })

      expect(message.content).to eq('')
    end

    it 'keeps nil content for messages without tool calls' do
      message = described_class.new(role: :assistant, content: nil, tool_calls: nil)

      expect(message.content).to be_nil
    end
  end
end
