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
