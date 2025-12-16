# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ToolCall do
  describe '#initialize' do
    it 'creates a tool call with required attributes' do
      tool_call = described_class.new(id: 'test-id', name: 'test_tool', arguments: { foo: 'bar' })

      expect(tool_call.id).to eq('test-id')
      expect(tool_call.name).to eq('test_tool')
      expect(tool_call.arguments).to eq({ foo: 'bar' })
    end

    it 'defaults arguments to empty hash' do
      tool_call = described_class.new(id: 'test-id', name: 'test_tool')

      expect(tool_call.arguments).to eq({})
    end

    it 'accepts and stores thought_signature parameter' do
      tool_call = described_class.new(
        id: 'test-id',
        name: 'test_tool',
        arguments: {},
        thought_signature: 'gemini-signature-123'
      )

      expect(tool_call.thought_signature).to eq('gemini-signature-123')
    end

    it 'defaults thought_signature to nil' do
      tool_call = described_class.new(id: 'test-id', name: 'test_tool')

      expect(tool_call.thought_signature).to be_nil
    end
  end

  describe '#to_h' do
    it 'returns hash representation of tool call' do
      tool_call = described_class.new(id: 'test-id', name: 'test_tool', arguments: { foo: 'bar' })

      expect(tool_call.to_h).to eq({
                                     id: 'test-id',
                                     name: 'test_tool',
                                     arguments: { foo: 'bar' }
                                   })
    end

    it 'includes thought_signature in hash when present' do
      tool_call = described_class.new(
        id: 'test-id',
        name: 'test_tool',
        arguments: {},
        thought_signature: 'signature-123'
      )

      hash = tool_call.to_h
      expect(hash[:thought_signature]).to eq('signature-123')
    end

    it 'excludes thought_signature from hash when nil' do
      tool_call = described_class.new(id: 'test-id', name: 'test_tool', arguments: {})

      hash = tool_call.to_h
      expect(hash).not_to have_key(:thought_signature)
    end
  end
end
