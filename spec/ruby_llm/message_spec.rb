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

    it 'preserves string-keyed hashes as structured content' do
      payload = { 'name' => 'Alice', 'age' => 25 }
      message = described_class.new(role: :assistant, content: payload)

      expect(message.content).to eq(payload)
    end

    it 'keeps symbol-keyed attachment hashes as content objects' do
      image_path = File.expand_path('../fixtures/ruby.png', __dir__)
      message = described_class.new(role: :user, content: { image: image_path })

      expect(message.content).to be_a(RubyLLM::Content)
      expect(message.content.attachments.first.filename).to eq('ruby.png')
    end
  end

  describe RubyLLM::Content::Raw do
    describe '#to_s' do
      it 'serializes hashes to JSON strings' do
        raw = described_class.new({ 'name' => 'Alice', 'age' => 25 })

        expect(raw.to_s).to eq('{"name":"Alice","age":25}')
      end

      it 'returns string payloads unchanged' do
        raw = described_class.new('hello')

        expect(raw.to_s).to eq('hello')
      end
    end
  end
end
