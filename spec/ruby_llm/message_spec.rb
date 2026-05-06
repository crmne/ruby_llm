# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Message do
  describe '#cache_point?' do
    it 'returns false by default' do
      message = described_class.new(role: :user, content: 'hello')
      expect(message.cache_point?).to be false
    end

    it 'returns true when constructed with cache_point: true' do
      message = described_class.new(role: :user, content: 'hello', cache_point: true)
      expect(message.cache_point?).to be true
    end
  end

  describe '#to_h' do
    it 'omits cache_point key when false' do
      message = described_class.new(role: :user, content: 'hello')
      expect(message.to_h).not_to have_key(:cache_point)
    end

    it 'includes cache_point: true when set' do
      message = described_class.new(role: :user, content: 'hello', cache_point: true)
      expect(message.to_h[:cache_point]).to be true
    end
  end

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
