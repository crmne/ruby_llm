# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::StreamAccumulator do
  describe '#to_message' do
    it 'keeps the last non-nil finish_reason from streamed chunks' do
      accumulator = described_class.new

      accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: 'hel'))
      accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: 'lo', finish_reason: 'length'))

      message = accumulator.to_message(instance_double(Faraday::Response))

      expect(message.content).to eq('hello')
      expect(message.finish_reason).to eq('length')
    end
  end

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
