# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Cost do
  let(:model) do
    RubyLLM::Model::Info.new(
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
      tokens = RubyLLM::Tokens.new(input: 1_000, output: 2_000, cached: 300, cache_creation: 100)
      cost = described_class.new(tokens:, model:)

      expect(cost.input).to be_within(0.0000000001).of(0.001)
      expect(cost.output).to be_within(0.0000000001).of(0.004)
      expect(cost.cache_read).to be_within(0.0000000001).of(0.000075)
      expect(cost.cache_write).to be_within(0.0000000001).of(0.000125)
      expect(cost.total).to be_within(0.0000000001).of(0.0052)
    end

    it 'trusts input tokens as the standard input bucket' do
      tokens = RubyLLM::Tokens.new(input: 700, cached: 300)
      cost = described_class.new(tokens:, model:)

      expect(cost.input).to be_within(0.0000000001).of(0.0007)
      expect(cost.cache_read).to be_within(0.0000000001).of(0.000075)
      expect(cost.total).to be_within(0.0000000001).of(0.000775)
    end

    it 'keeps backwards-compatible cache cost aliases' do
      tokens = RubyLLM::Tokens.new(input: 1_000, cached: 300, cache_creation: 100)
      cost = described_class.new(tokens:, model:)

      expect(cost.cached_input).to eq(cost.cache_read)
      expect(cost.cache_creation).to eq(cost.cache_write)
    end

    it 'reads legacy cache pricing keys' do
      legacy_model = RubyLLM::Model::Info.new(
        id: 'legacy-priced-model',
        name: 'Legacy Priced Model',
        provider: 'openai',
        pricing: {
          text_tokens: {
            standard: {
              cached_input_per_million: 0.25,
              cache_creation_input_per_million: 1.25
            }
          }
        }
      )
      tokens = RubyLLM::Tokens.new(cached: 300, cache_creation: 100)
      cost = described_class.new(tokens:, model: legacy_model)

      expect(cost.cache_read).to be_within(0.0000000001).of(0.000075)
      expect(cost.cache_write).to be_within(0.0000000001).of(0.000125)
    end

    it 'returns nil when pricing is missing for tokens that were used' do
      incomplete_model = RubyLLM::Model::Info.new(
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
      input_only_model = RubyLLM::Model::Info.new(
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
end
