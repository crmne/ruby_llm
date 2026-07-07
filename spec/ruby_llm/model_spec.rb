# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Model do
  subject(:model) { described_class.new(data) }

  let(:data) do
    {
      id: 'gpt-5',
      name: 'GPT-5',
      provider: 'openai',
      family: 'gpt',
      created_at: '2026-02-20 00:00:00 UTC',
      context_window: 400_000,
      max_output_tokens: 128_000,
      knowledge_cutoff: '2025-10-01',
      modalities: { input: %w[text image], output: %w[text] },
      capabilities: %w[function_calling streaming vision structured_output],
      pricing: { text_tokens: { standard: { input: 2.50, output: 10.00 } } },
      metadata: {
        description: 'A test model',
        reasoning_options: [
          { type: 'effort', values: %w[low medium high] },
          { type: 'budget_tokens', min: 1024 }
        ]
      }
    }
  end

  describe '#initialize' do
    it 'assigns basic attributes' do
      expect(model).to have_attributes(
        id: 'gpt-5',
        name: 'GPT-5',
        provider: 'openai',
        family: 'gpt',
        context_window: 400_000,
        max_output_tokens: 128_000
      )
    end

    it 'parses created_at and knowledge_cutoff' do
      expect(model.created_at).to be_a(Time)
      expect(model.knowledge_cutoff).to be_a(Date)
    end

    it 'normalizes time to UTC' do
      model = described_class.new(created_at: '2026-02-20 00:00:00 +0700')
      expect(model.created_at).to be_utc
      expect(model.created_at).to eq Time.new(2026, 2, 19, 17, 0, 0, '+00:00')
    end

    it 'builds modalities' do
      expect(model.modalities).to be_a(RubyLLM::Model::Modalities)
      expect(model.modalities.input).to eq(%w[text image])
      expect(model.modalities.output).to eq(%w[text])
    end

    it 'builds pricing' do
      expect(model.pricing).to be_a(RubyLLM::Model::Pricing)
    end

    it 'defaults missing optional fields' do
      minimal = described_class.new(id: 'test', name: 'Test', provider: 'openai')

      expect(minimal.capabilities).to eq([])
      expect(minimal.metadata).to eq({})
      expect(minimal.reasoning_options).to eq([])
      expect(minimal.modalities.input).to eq([])
    end
  end

  describe '.default' do
    subject(:default_model) { described_class.default('my-custom-model', 'openai') }

    it 'creates a model with assumed capabilities' do
      expect(default_model).to have_attributes(
        id: 'my-custom-model',
        provider: 'openai'
      )
      expect(default_model.capabilities).to include('function_calling', 'streaming')
      expect(default_model.metadata).to have_key(:warning)
    end
  end

  describe '#supports?' do
    it 'returns true for included capabilities, as symbol or string' do
      expect(model.supports?(:function_calling)).to be true
      expect(model.supports?('streaming')).to be true
      expect(model.supports?(:vision)).to be true
    end

    it 'returns false for capabilities absent from the registry data' do
      expect(model.supports?(:batch)).to be false

      text_only = described_class.new(data.merge(capabilities: %w[function_calling streaming structured_output]))
      expect(text_only.supports?(:vision)).to be false
    end
  end

  describe '#reasoning_options' do
    it 'normalizes metadata reasoning options' do
      expect(model.reasoning_options).to eq(
        [
          { type: 'effort', values: %w[low medium high] },
          { type: 'budget_tokens', min: 1024 }
        ]
      )
    end

    it 'accepts top-level reasoning options and stores them in metadata' do
      top_level_model = described_class.new(
        data.merge(
          reasoning_options: [
            { 'type' => 'effort', 'values' => %i[low high] }
          ],
          metadata: {}
        )
      )

      expect(top_level_model.reasoning_options).to eq([{ type: 'effort', values: %w[low high] }])
      expect(top_level_model.metadata[:reasoning_options]).to eq([{ type: 'effort', values: %w[low high] }])
    end

    it 'accepts string-keyed metadata reasoning options' do
      legacy_model = described_class.new(
        data.merge(
          metadata: {
            'reasoning_options' => [
              { 'type' => 'effort', 'values' => %i[low high] }
            ]
          }
        )
      )

      expect(legacy_model.reasoning_options).to eq([{ type: 'effort', values: %w[low high] }])
    end

    it 'prefers top-level reasoning options over metadata when both are present' do
      model = described_class.new(
        data.merge(
          reasoning_options: [
            { 'type' => 'effort', 'values' => %w[low high] }
          ],
          metadata: {
            reasoning_options: [
              { 'type' => 'budget_tokens', 'min' => 1024 }
            ]
          }
        )
      )

      expect(model.reasoning_options).to eq([{ type: 'effort', values: %w[low high] }])
    end

    it 'normalizes option values to strings' do
      symbol_model = described_class.new(
        data.merge(
          metadata: {
            reasoning_options: [
              { 'type' => 'effort', 'values' => %i[low high] }
            ]
          }
        )
      )

      expect(symbol_model.reasoning_options).to eq([{ type: 'effort', values: %w[low high] }])
    end

    it 'returns option values by type' do
      expect(model.reasoning_option_values(:effort)).to eq(%w[low medium high])
      expect(model.reasoning_option_values(:budget_tokens)).to eq([])
    end
  end

  describe '#type' do
    it 'returns chat for text output models' do
      expect(model.type).to eq('chat')
    end

    it 'returns embedding for output models that include embeddings' do
      embedding = described_class.new(data.merge(modalities: { input: %w[text], output: %w[embeddings] }))
      expect(embedding.type).to eq('embedding')
    end

    it 'returns image for output models that include image' do
      image = described_class.new(data.merge(modalities: { input: %w[text], output: %w[image] }))
      expect(image.type).to eq('image')
    end

    it 'returns image for mixed text+image output models' do
      image = described_class.new(data.merge(modalities: { input: %w[text], output: %w[text image] }))
      expect(image.type).to eq('image')
    end

    it 'returns audio for mixed text+audio output models' do
      audio = described_class.new(data.merge(modalities: { input: %w[text], output: %w[text audio] }))
      expect(audio.type).to eq('audio')
    end

    it 'returns embedding for mixed text+embeddings output models' do
      embedding = described_class.new(data.merge(modalities: { input: %w[text], output: %w[text embeddings] }))
      expect(embedding.type).to eq('embedding')
    end

    it 'returns moderation for mixed text+moderation output models' do
      moderation = described_class.new(data.merge(modalities: { input: %w[text], output: %w[text moderation] }))
      expect(moderation.type).to eq('moderation')
    end

    it 'returns video for video output models' do
      video = described_class.new(data.merge(modalities: { input: %w[text], output: %w[video] }))
      expect(video.type).to eq('video')
    end
  end

  describe '#label' do
    it 'returns the provider and model name' do
      expect(model.label).to eq('OpenAI - GPT-5')
    end
  end

  describe '#price' do
    it 'returns the standard text-token price for a kind' do
      expect(model.price(:input)).to eq(model.pricing.text_tokens.input)
      expect(model.price(:output)).to eq(model.pricing.text_tokens.output)
    end

    it 'reads cache read and write prices' do
      cached = described_class.new(
        data.merge(
          pricing: {
            text_tokens: {
              standard: {
                cache_read_input_per_million: 0.5,
                cache_write_input_per_million: 2.5
              }
            }
          }
        )
      )

      expect(cached.price(:cache_read)).to eq(0.5)
      expect(cached.price(:cache_write)).to eq(2.5)
    end

    it 'raises for an unknown kind' do
      expect { model.price(:bogus) }.to raise_error(ArgumentError, /Unknown price kind/)
    end
  end

  describe '#cost_for' do
    it 'builds a Cost for the supplied tokens' do
      model = described_class.new(
        data.merge(
          pricing: {
            text_tokens: {
              standard: {
                input_per_million: 2.50,
                output_per_million: 10.00
              }
            }
          }
        )
      )
      tokens = RubyLLM::Tokens.new(input: 1_000, output: 2_000)

      expect(model.cost_for(tokens).total).to eq(0.0225)
    end
  end

  describe '#to_h' do
    it 'returns a hash representation' do
      hash = model.to_h

      expect(hash[:id]).to eq('gpt-5')
      expect(hash[:provider]).to eq('openai')
      expect(hash[:modalities]).to be_a(Hash)
      expect(hash[:pricing]).to be_a(Hash)
      expect(hash[:capabilities]).to include('function_calling')
      expect(hash).not_to have_key(:reasoning_options)
      expect(hash[:metadata][:reasoning_options]).to eq(
        [
          { type: 'effort', values: %w[low medium high] },
          { type: 'budget_tokens', min: 1024 }
        ]
      )
    end
  end
end
