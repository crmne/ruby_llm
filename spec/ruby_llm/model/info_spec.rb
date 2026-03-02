# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Model::Info do
  subject(:info) { described_class.new(data) }

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
      metadata: { description: 'A test model' }
    }
  end

  describe '#initialize' do
    it 'assigns basic attributes' do
      expect(info).to have_attributes(
        id: 'gpt-5',
        name: 'GPT-5',
        provider: 'openai',
        family: 'gpt',
        context_window: 400_000,
        max_output_tokens: 128_000
      )
    end

    it 'parses created_at and knowledge_cutoff' do
      expect(info.created_at).to be_a(Time)
      expect(info.knowledge_cutoff).to be_a(Date)
    end

    it 'normalizes time to UTC' do
      info = described_class.new(created_at: '2026-02-20 00:00:00 +0700')
      expect(info.created_at).to be_utc
      expect(info.created_at).to eq Time.new(2026, 2, 19, 17, 0, 0, '+00:00')
    end

    it 'builds modalities' do
      expect(info.modalities).to be_a(RubyLLM::Model::Modalities)
      expect(info.modalities.input).to eq(%w[text image])
      expect(info.modalities.output).to eq(%w[text])
    end

    it 'builds pricing' do
      expect(info.pricing).to be_a(RubyLLM::Model::Pricing)
    end

    it 'defaults missing optional fields' do
      minimal = described_class.new(id: 'test', name: 'Test', provider: 'openai')

      expect(minimal.capabilities).to eq([])
      expect(minimal.metadata).to eq({})
      expect(minimal.modalities.input).to eq([])
    end
  end

  describe '.default' do
    subject(:default_info) { described_class.default('my-custom-model', 'openai') }

    it 'creates an info with assumed capabilities' do
      expect(default_info).to have_attributes(
        id: 'my-custom-model',
        provider: 'openai'
      )
      expect(default_info.capabilities).to include('function_calling', 'streaming')
      expect(default_info.metadata).to have_key(:warning)
    end
  end

  describe '#supports?' do
    it 'returns true for included capabilities' do
      expect(info.supports?(:function_calling)).to be true
      expect(info.supports?('streaming')).to be true
    end

    it 'returns false for missing capabilities' do
      expect(info.supports?(:batch)).to be false
    end
  end

  describe 'capability predicates' do
    it 'responds to dynamic capability methods' do
      expect(info.function_calling?).to be true
      expect(info.structured_output?).to be true
      expect(info.streaming?).to be true
      expect(info.batch?).to be false
      expect(info.reasoning?).to be false
    end
  end

  describe '#supports_vision?' do
    it 'returns true when image is in input modalities' do
      expect(info.supports_vision?).to be true
    end

    it 'returns false when image is not in input modalities' do
      text_only = described_class.new(data.merge(modalities: { input: %w[text], output: %w[text] }))
      expect(text_only.supports_vision?).to be false
    end
  end

  describe '#type' do
    it 'returns chat for text output models' do
      expect(info.type).to eq('chat')
    end

    it 'returns embedding for embedding-only output models' do
      embedding = described_class.new(data.merge(modalities: { input: %w[text], output: %w[embeddings] }))
      expect(embedding.type).to eq('embedding')
    end

    it 'returns image for image-only output models' do
      image = described_class.new(data.merge(modalities: { input: %w[text], output: %w[image] }))
      expect(image.type).to eq('image')
    end
  end

  describe '#display_name' do
    it 'returns the name' do
      expect(info.display_name).to eq('GPT-5')
    end
  end

  describe '#max_tokens' do
    it 'returns max_output_tokens' do
      expect(info.max_tokens).to eq(128_000)
    end
  end

  describe '#input_price_per_million and #output_price_per_million' do
    it 'delegates to pricing' do
      expect(info.input_price_per_million).to eq(info.pricing.text_tokens.input)
      expect(info.output_price_per_million).to eq(info.pricing.text_tokens.output)
    end
  end

  describe '#to_h' do
    it 'returns a hash representation' do
      hash = info.to_h

      expect(hash[:id]).to eq('gpt-5')
      expect(hash[:provider]).to eq('openai')
      expect(hash[:modalities]).to be_a(Hash)
      expect(hash[:pricing]).to be_a(Hash)
      expect(hash[:capabilities]).to include('function_calling')
    end
  end
end
