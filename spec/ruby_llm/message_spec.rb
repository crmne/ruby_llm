# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Message do
  let(:model) do
    RubyLLM::Model::Info.new(
      id: 'priced-model',
      name: 'Priced Model',
      provider: 'openai',
      pricing: {
        text_tokens: {
          standard: {
            input_per_million: 1.0,
            output_per_million: 2.0
          }
        }
      }
    )
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

  describe '#cost' do
    it 'calculates cost from the supplied model' do
      message = described_class.new(role: :assistant, content: 'Hello', input_tokens: 1_000, output_tokens: 2_000)

      expect(message.cost(model: model).total).to eq(0.005)
      expect(message.cost(model: model).to_h).to include(input: 0.001, output: 0.004, total: 0.005)
    end

    it 'uses model_id for cost lookup' do
      allow(RubyLLM.models).to receive(:find).and_call_original
      allow(RubyLLM.models).to receive(:find).with('priced-model').and_return(model)

      message = described_class.new(
        role: :assistant,
        content: 'Hello',
        input_tokens: 1_000,
        output_tokens: 2_000,
        model_id: 'priced-model'
      )

      expect(message.cost.total).to eq(0.005)
    end

    it 'returns nil when the message model cannot be found' do
      message = described_class.new(
        role: :assistant,
        content: 'Hello',
        input_tokens: 1_000,
        model_id: 'missing-model'
      )

      expect(message.cost.total).to be_nil
    end
  end

  describe 'cache token aliases' do
    it 'exposes cache_read_tokens and cache_write_tokens' do
      message = described_class.new(
        role: :assistant,
        content: 'Hello',
        cached_tokens: 42,
        cache_creation_tokens: 7
      )

      expect(message.cache_read_tokens).to eq(42)
      expect(message.cache_write_tokens).to eq(7)
      expect(message.tokens.cache_read).to eq(42)
      expect(message.tokens.cache_write).to eq(7)
    end
  end
end
