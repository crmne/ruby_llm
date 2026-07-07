# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Cost do
  let(:model) do
    RubyLLM::Model.new(
      id: 'priced-model',
      name: 'Priced Model',
      provider: 'openai',
      pricing: {
        text_tokens: {
          standard: {
            input_per_million: 1.0,
            output_per_million: 2.0,
            cache_read_input_per_million: 0.25,
            cache_write_input_per_million: 1.25
          }
        }
      }
    )
  end

  describe '#total' do
    it 'calculates input, output, cache read, and cache write costs from normalized token buckets' do
      tokens = RubyLLM::Tokens.new(input: 1_000, output: 2_000, cache_read: 300, cache_write: 100)
      cost = described_class.new(tokens:, model:)

      expect(cost.input).to be_within(0.0000000001).of(0.001)
      expect(cost.output).to be_within(0.0000000001).of(0.004)
      expect(cost.cache_read).to be_within(0.0000000001).of(0.000075)
      expect(cost.cache_write).to be_within(0.0000000001).of(0.000125)
      expect(cost.total).to be_within(0.0000000001).of(0.0052)
    end

    it 'trusts input tokens as the standard input bucket' do
      tokens = RubyLLM::Tokens.new(input: 700, cache_read: 300)
      cost = described_class.new(tokens:, model:)

      expect(cost.input).to be_within(0.0000000001).of(0.0007)
      expect(cost.cache_read).to be_within(0.0000000001).of(0.000075)
      expect(cost.total).to be_within(0.0000000001).of(0.000775)
    end

    it 'calculates image costs from text and image input details' do
      image_model = RubyLLM::Model.new(
        id: 'image-model',
        name: 'Image Model',
        provider: 'openai',
        pricing: {
          text_tokens: {
            standard: {
              input_per_million: 5.0
            }
          },
          images: {
            standard: {
              input_per_million: 10.0,
              output_per_million: 40.0
            }
          }
        }
      )
      tokens = RubyLLM::Tokens.new(input: 350, output: 50)
      cost = described_class.new(
        tokens:,
        model: image_model,
        category: :images,
        input_details: {
          'text_tokens' => 100,
          'image_tokens' => 250
        }
      )

      expect(cost.input).to be_within(0.0000000001).of(0.003)
      expect(cost.output).to be_within(0.0000000001).of(0.002)
      expect(cost.total).to be_within(0.0000000001).of(0.005)
    end

    it 'does not price thinking tokens separately when output already includes them' do
      tokens = RubyLLM::Tokens.new(input: 50, output: 1306, thinking: 1087)
      cost = described_class.new(tokens:, model:)

      expect(cost.output).to be_within(0.0000000001).of(0.002612)
      expect(cost.thinking).to be_nil
      expect(cost.total).to be_within(0.0000000001).of(0.002662)
    end

    it 'prices thinking tokens separately when the model has distinct reasoning pricing' do
      reasoning_model = RubyLLM::Model.new(
        id: 'reasoning-priced-model',
        name: 'Reasoning Priced Model',
        provider: 'perplexity',
        pricing: {
          text_tokens: {
            standard: {
              input_per_million: 2.0,
              output_per_million: 8.0,
              reasoning_output_per_million: 3.0
            }
          }
        }
      )
      tokens = RubyLLM::Tokens.new(input: 33, output: 11_395, thinking: 193_947)
      cost = described_class.new(tokens:, model: reasoning_model)

      expect(cost.input).to be_within(0.0000000001).of(0.000066)
      expect(cost.output).to be_within(0.0000000001).of(0.09116)
      expect(cost.thinking).to be_within(0.0000000001).of(0.581841)
      expect(cost.total).to be_within(0.0000000001).of(0.673067)
    end

    it 'does not double-count thinking tokens when reasoning pricing matches output pricing' do
      inclusive_model = RubyLLM::Model.new(
        id: 'inclusive-reasoning-model',
        name: 'Inclusive Reasoning Model',
        provider: 'openrouter',
        pricing: {
          text_tokens: {
            standard: {
              output_per_million: 12.0,
              reasoning_output_per_million: 12.0
            }
          }
        }
      )
      tokens = RubyLLM::Tokens.new(output: 1_000, thinking: 800)
      cost = described_class.new(tokens:, model: inclusive_model)

      expect(cost.output).to eq(0.012)
      expect(cost.thinking).to be_nil
      expect(cost.total).to eq(0.012)
    end

    it 'returns nil when pricing is missing for tokens that were used' do
      incomplete_model = RubyLLM::Model.new(
        id: 'incomplete-model',
        name: 'Incomplete Model',
        provider: 'openai',
        pricing: { text_tokens: { standard: { input_per_million: 1.0 } } }
      )
      tokens = RubyLLM::Tokens.new(input: 10, output: 5)
      cost = described_class.new(tokens:, model: incomplete_model)

      expect(cost.input).to eq(0.00001)
      expect(cost.output).to be_nil
      expect(cost.total).to be_nil
    end

    it 'does not require pricing for token buckets that were not used' do
      input_only_model = RubyLLM::Model.new(
        id: 'input-only-model',
        name: 'Input Only Model',
        provider: 'openai',
        pricing: { text_tokens: { standard: { input_per_million: 1.0 } } }
      )
      tokens = RubyLLM::Tokens.new(input: 10)
      cost = described_class.new(tokens:, model: input_only_model)

      expect(cost.output).to be_nil
      expect(cost.total).to eq(0.00001)
    end

    it 'returns nil when there is no token usage' do
      expect(described_class.new(model: model).total).to be_nil
    end
  end

  describe '.aggregate' do
    it 'sums costs while preserving nil for missing pricing' do
      priced = described_class.new(tokens: RubyLLM::Tokens.new(input: 10), model:)
      missing = described_class.new(tokens: RubyLLM::Tokens.new(output: 10), model: nil)
      aggregate = described_class.aggregate([priced, missing])

      expect(aggregate.input).to eq(0.00001)
      expect(aggregate.output).to be_nil
      expect(aggregate.total).to be_nil
    end

    it 'ignores entries without token usage' do
      priced = described_class.new(tokens: RubyLLM::Tokens.new(input: 10), model:)
      empty = described_class.new(model: model)
      aggregate = described_class.aggregate([empty, priced])

      expect(aggregate.total).to eq(0.00001)
    end
  end

  describe '.from_h' do
    it 'reads component amounts and total from a stored breakdown' do
      cost = described_class.from_h('input' => 0.001, 'output' => 0.004, 'total' => 0.005)

      expect(cost.input).to eq(0.001)
      expect(cost.output).to eq(0.004)
      expect(cost.cache_read).to be_nil
      expect(cost.total).to eq(0.005)
    end

    it 'accepts symbol keys' do
      cost = described_class.from_h(input: 0.001, output: 0.004, total: 0.005)

      expect(cost.total).to eq(0.005)
    end

    it 'round-trips a live cost through to_h' do
      live = described_class.new(tokens: RubyLLM::Tokens.new(input: 1_000, output: 2_000), model:)
      restored = described_class.from_h(live.to_h)

      expect(restored.to_h).to eq(live.to_h)
      expect(restored.total).to eq(live.total)
    end

    it 'returns a nil total when the stored breakdown recorded no total' do
      cost = described_class.from_h('input' => 0.001)

      expect(cost.input).to eq(0.001)
      expect(cost.total).to be_nil
    end

    it 'aggregates several stored costs' do
      a = described_class.from_h('input' => 0.001, 'output' => 0.004, 'total' => 0.005)
      b = described_class.from_h('input' => 0.0005, 'output' => 0.002, 'total' => 0.0025)
      aggregate = described_class.aggregate([a, b])

      expect(aggregate.input).to be_within(0.0000000001).of(0.0015)
      expect(aggregate.output).to be_within(0.0000000001).of(0.006)
      expect(aggregate.total).to be_within(0.0000000001).of(0.0075)
    end

    it 'aggregates a stored cost mixed with a live cost' do
      stored = described_class.from_h('input' => 0.001, 'output' => 0.004, 'total' => 0.005)
      live = described_class.new(tokens: RubyLLM::Tokens.new(input: 1_000), model:)
      aggregate = described_class.aggregate([stored, live])

      expect(aggregate.input).to be_within(0.0000000001).of(0.002)
      expect(aggregate.output).to eq(0.004)
      expect(aggregate.total).to be_within(0.0000000001).of(0.006)
    end
  end
end
