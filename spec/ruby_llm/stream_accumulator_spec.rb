# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::StreamAccumulator do
  describe '#add' do
    it 'handles tool call deltas that omit arguments' do
      accumulator = described_class.new
      tool_call = RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: nil)
      chunk = RubyLLM::Chunk.new(role: :assistant, content: nil, tool_calls: { 'call_1' => tool_call })

      expect { accumulator.add(chunk) }.not_to raise_error

      message = accumulator.to_message(nil)
      expect(message.tool_calls['call_1'].arguments).to eq({})
    end
  end
end
