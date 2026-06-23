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

  describe '#to_h' do
    it 'includes finish_reason when present' do
      message = described_class.new(role: :assistant, content: 'Hello', finish_reason: 'length')

      expect(message.finish_reason).to eq('length')
      expect(message.to_h[:finish_reason]).to eq('length')
    end
  end

  describe 'finish reason predicates' do
    {
      stopped?: %w[stop end_turn STOP stop_sequence],
      max_tokens?: %w[length max_tokens MAX_TOKENS max_output_tokens model_context_window_exceeded],
      tool_call_stop?: %w[tool_calls tool_use function_call],
      content_filtered?: %w[
        content_filter content-filter SAFETY guardrail_intervened RECITATION BLOCKLIST
        PROHIBITED_CONTENT SPII image_safety model_armor
      ]
    }.each do |predicate, finish_reasons|
      it "returns true for #{predicate} when finish_reason matches common provider values" do
        finish_reasons.each do |finish_reason|
          message = described_class.new(role: :assistant, content: 'Hello', finish_reason: finish_reason)

          expect(message.public_send(predicate)).to be(true)
        end
      end
    end

    it 'returns false when finish_reason is nil or unknown' do
      nil_message = described_class.new(role: :assistant, content: 'Hello', finish_reason: nil)
      unknown_message = described_class.new(role: :assistant, content: 'Hello', finish_reason: 'weird_provider_value')

      %i[stopped? max_tokens? tool_call_stop? content_filtered?].each do |predicate|
        expect(nil_message.public_send(predicate)).to be(false)
        expect(unknown_message.public_send(predicate)).to be(false)
      end
    end

    it 'is inherited by streaming chunks' do
      chunk = RubyLLM::Chunk.new(role: :assistant, content: nil, finish_reason: 'MAX_TOKENS')

      expect(chunk.max_tokens?).to be(true)
    end
  end
end
