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

    it 'uses long-context rates when the prompt exceeds the model threshold' do
      long_context_model = RubyLLM::Model.new(
        id: 'gpt-5.6-sol',
        name: 'GPT-5.6 Sol',
        provider: 'openai',
        pricing: {
          text_tokens: {
            standard: {
              input_per_million: 5.0,
              output_per_million: 30.0,
              cache_read_input_per_million: 0.5
            },
            long_context: {
              input_per_million: 10.0,
              output_per_million: 45.0,
              cache_read_input_per_million: 1.0
            },
            long_context_threshold: 272_000
          }
        }
      )

      short = described_class.new(
        tokens: RubyLLM::Tokens.new(input: 100_000, output: 10_000),
        model: long_context_model
      )
      long = described_class.new(
        tokens: RubyLLM::Tokens.new(input: 500_000, output: 10_000),
        model: long_context_model
      )

      expect(short.total).to be_within(0.0000000001).of(0.8)
      expect(long.total).to be_within(0.0000000001).of(5.45)
    end

    it 'counts cache tokens toward the long-context prompt threshold' do
      long_context_model = RubyLLM::Model.new(
        id: 'gpt-5.6-sol',
        name: 'GPT-5.6 Sol',
        provider: 'openai',
        pricing: {
          text_tokens: {
            standard: {
              input_per_million: 5.0,
              output_per_million: 30.0,
              cache_read_input_per_million: 0.5
            },
            long_context: {
              input_per_million: 10.0,
              output_per_million: 45.0,
              cache_read_input_per_million: 1.0
            },
            long_context_threshold: 272_000
          }
        }
      )
      cost = described_class.new(
        tokens: RubyLLM::Tokens.new(input: 100_000, output: 1_000, cache_read: 200_000),
        model: long_context_model
      )

      expect(cost.input).to be_within(0.0000000001).of(1.0)
      expect(cost.cache_read).to be_within(0.0000000001).of(0.2)
      expect(cost.output).to be_within(0.0000000001).of(0.045)
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

  describe 'provider-reported cost' do
    it 'prefers the reported cost over the registry estimate' do
      tokens = RubyLLM::Tokens.new(input: 1_000, output: 2_000, reported_cost: 0.0042)
      cost = described_class.new(tokens:, model:)

      expect(cost.input).to be_within(0.0000000001).of(0.001)
      expect(cost.total).to eq(0.0042)
    end

    it 'returns the reported cost when registry pricing is missing' do
      tokens = RubyLLM::Tokens.new(input: 10, output: 5, reported_cost: 0.0042)
      cost = described_class.new(tokens:, model: nil)

      expect(cost.input).to be_nil
      expect(cost.total).to eq(0.0042)
    end

    it 'reports usage even when the provider returned only a cost' do
      tokens = RubyLLM::Tokens.new(reported_cost: 0.0042)
      cost = described_class.new(tokens:, model: nil)

      expect(cost.tokens?).to be(true)
      expect(cost.total).to eq(0.0042)
    end

    it 'estimates from the registry when no cost was reported' do
      tokens = RubyLLM::Tokens.new(input: 1_000, output: 2_000)
      cost = described_class.new(tokens:, model:)

      expect(cost.total).to be_within(0.0000000001).of(0.005)
    end

    it 'sums reported costs across aggregated attempts' do
      first = described_class.new(tokens: RubyLLM::Tokens.new(input: 10, reported_cost: 0.001), model: nil)
      second = described_class.new(tokens: RubyLLM::Tokens.new(input: 20, reported_cost: 0.002), model: nil)
      aggregate = described_class.aggregate([first, second])

      expect(aggregate.total).to be_within(0.0000000001).of(0.003)
    end

    it 'mixes reported and estimated totals in an aggregate' do
      reported = described_class.new(tokens: RubyLLM::Tokens.new(input: 10, reported_cost: 0.001), model: nil)
      estimated = described_class.new(tokens: RubyLLM::Tokens.new(input: 1_000, output: 2_000), model:)
      aggregate = described_class.aggregate([reported, estimated])

      expect(aggregate.total).to be_within(0.0000000001).of(0.006)
    end

    it 'round-trips the reported total through to_h' do
      tokens = RubyLLM::Tokens.new(input: 10, output: 5, reported_cost: 0.0042)
      restored = described_class.from_h(described_class.new(tokens:, model: nil).to_h)

      expect(restored.total).to eq(0.0042)
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
      cost = described_class.from_h({ 'input' => 0.001, 'output' => 0.004, 'total' => 0.005 })

      expect(cost.input).to eq(0.001)
      expect(cost.output).to eq(0.004)
      expect(cost.cache_read).to be_nil
      expect(cost.total).to eq(0.005)
    end

    it 'accepts symbol keys' do
      cost = described_class.from_h({ input: 0.001, output: 0.004, total: 0.005 })

      expect(cost.total).to eq(0.005)
    end

    it 'preserves a recorded total when component costs were not stored' do
      cost = described_class.from_h({ total: 0.005 })

      expect(cost.total).to eq(0.005)
    end

    it 'keeps missing historical pricing missing when token usage is known' do
      tokens = RubyLLM::Tokens.new(input: 10)
      cost = described_class.from_h({}, tokens: tokens)

      expect(cost.input).to be_nil
      expect(cost.total).to be_nil
      expect(cost).to be_missing(:input)
    end

    it 'round-trips a live cost through to_h' do
      live = described_class.new(tokens: RubyLLM::Tokens.new(input: 1_000, output: 2_000), model:)
      restored = described_class.from_h(live.to_h)

      expect(restored.to_h).to eq(live.to_h)
      expect(restored.total).to eq(live.total)
    end

    it 'returns a nil total when the stored breakdown recorded no total' do
      cost = described_class.from_h({ 'input' => 0.001 })

      expect(cost.input).to eq(0.001)
      expect(cost.total).to be_nil
    end

    it 'aggregates several stored costs' do
      a = described_class.from_h({ 'input' => 0.001, 'output' => 0.004, 'total' => 0.005 })
      b = described_class.from_h({ 'input' => 0.0005, 'output' => 0.002, 'total' => 0.0025 })
      aggregate = described_class.aggregate([a, b])

      expect(aggregate.input).to be_within(0.0000000001).of(0.0015)
      expect(aggregate.output).to be_within(0.0000000001).of(0.006)
      expect(aggregate.total).to be_within(0.0000000001).of(0.0075)
    end

    it 'aggregates a stored cost mixed with a live cost' do
      stored = described_class.from_h({ 'input' => 0.001, 'output' => 0.004, 'total' => 0.005 })
      live = described_class.new(tokens: RubyLLM::Tokens.new(input: 1_000), model:)
      aggregate = described_class.aggregate([stored, live])

      expect(aggregate.input).to be_within(0.0000000001).of(0.002)
      expect(aggregate.output).to eq(0.004)
      expect(aggregate.total).to be_within(0.0000000001).of(0.006)
    end
  end

  describe 'incomplete aggregates' do
    it 'reports no total when one attempt is still unpriced' do
      cost = described_class.aggregate([described_class.new(tokens: RubyLLM::Tokens.new(input: 10), model:)],
                                       complete: false)

      expect(cost.input).to be_within(0.0000000001).of(0.00001)
      expect(cost.total).to be_nil
    end
  end

  describe 'model resolution' do
    it 'prices against a model looked up by id' do
      cost = described_class.new(tokens: RubyLLM::Tokens.new(input: 1_000_000), model: 'gpt-4.1-nano')

      expect(cost.input).to be_positive
    end

    it 'prices against anything that converts to a model' do
      wrapper = Struct.new(:to_llm).new(model)

      expect(described_class.new(tokens: RubyLLM::Tokens.new(input: 1_000), model: wrapper).input).to eq(0.001)
    end

    it 'reports nothing for a model id it cannot find' do
      cost = described_class.new(tokens: RubyLLM::Tokens.new(input: 1_000), model: 'no-such-model-12345')

      expect(cost.input).to be_nil
      expect(cost.total).to be_nil
    end

    it 'reports nothing for a value that is not a model at all' do
      expect(described_class.new(tokens: RubyLLM::Tokens.new(input: 1_000), model: 42).input).to be_nil
    end
  end

  describe 'non-text pricing categories' do
    let(:audio_model) do
      RubyLLM::Model.new(
        id: 'audio-model',
        name: 'Audio Model',
        provider: 'openai',
        pricing: { audio_tokens: { standard: { input_per_million: 4.0, output_per_million: 8.0 } } }
      )
    end

    it 'prices a named category' do
      cost = described_class.new(
        tokens: RubyLLM::Tokens.new(input: 1_000_000, output: 1_000_000),
        model: audio_model, category: :audio_tokens
      )

      expect(cost.input).to eq(4.0)
      expect(cost.output).to eq(8.0)
    end

    it 'reports nothing for a category the pricing does not know' do
      cost = described_class.new(
        tokens: RubyLLM::Tokens.new(input: 1_000), model: audio_model, category: :video_tokens
      )

      expect(cost.input).to be_nil
    end
  end

  describe '#to_h' do
    it 'omits the components that were never priced' do
      cost = described_class.new(tokens: RubyLLM::Tokens.new(input: 1_000), model:)

      expect(cost.to_h.keys).to contain_exactly(:input, :total)
    end
  end

  describe '.from_h edge cases' do
    it 'reports nothing when the stored breakdown is empty' do
      cost = described_class.from_h({})

      expect(cost.total).to be_nil
      expect(cost.tokens?).to be(false)
    end

    it 'trusts a recorded total even when components are missing' do
      cost = described_class.from_h({ 'total' => 0.005 })

      expect(cost.total).to eq(0.005)
      expect(cost.tokens?).to be(true)
    end

    it 'flags components that had tokens but no recorded cost' do
      cost = described_class.from_h({ 'input' => 0.001 }, tokens: RubyLLM::Tokens.new(input: 10, output: 5))

      expect(cost.missing?(:output)).to be(true)
      expect(cost.total).to be_nil
    end
  end
end
