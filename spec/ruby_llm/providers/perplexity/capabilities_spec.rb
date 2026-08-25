# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Perplexity::Capabilities do
  describe '.model_family' do
    {
      'sonar' => :sonar,
      'sonar-pro' => :sonar_pro,
      'sonar-reasoning-pro' => :sonar_reasoning_pro,
      'sonar-deep-research' => :sonar_deep_research,
      'pplx-embed-v1-0.6b' => :pplx_embed_small,
      'pplx-embed-v1-4b' => :pplx_embed_large,
      'sonar-experimental' => :unknown
    }.each do |model_id, expected|
      it "groups #{model_id} under #{expected}" do
        expect(described_class.model_family(model_id)).to eq(expected)
      end
    end
  end

  describe '.context_window_for' do
    it 'gives sonar-pro the larger window' do
      expect(described_class.context_window_for('sonar-pro')).to eq(200_000)
      expect(described_class.context_window_for('sonar')).to eq(128_000)
      expect(described_class.context_window_for('pplx-embed-v1-0.6b')).to eq(32_768)
    end

    it 'leaves the resold third-party models nil' do
      expect(described_class.context_window_for('anthropic/claude-opus-5')).to be_nil
      expect(described_class.context_window_for('openai/gpt-5.4')).to be_nil
      expect(described_class.context_window_for('perplexity/kimi-k3')).to be_nil
      expect(described_class.context_window_for('perplexity/sonar')).to eq(128_000)
    end
  end

  describe '.max_tokens_for' do
    it 'gives the pro tiers the larger output budget' do
      expect(described_class.max_tokens_for('sonar-pro')).to eq(8_192)
      expect(described_class.max_tokens_for('sonar-reasoning-pro')).to eq(8_192)
      expect(described_class.max_tokens_for('sonar')).to eq(4_096)
      expect(described_class.max_tokens_for('pplx-embed-v1-4b')).to be_nil
    end

    it 'leaves the resold third-party models nil' do
      expect(described_class.max_tokens_for('anthropic/claude-opus-5')).to be_nil
      expect(described_class.max_tokens_for('google/gemini-3.7-flash')).to be_nil
      expect(described_class.max_tokens_for('perplexity/sonar')).to eq(4_096)
    end
  end

  describe '.critical_capabilities_for' do
    it 'claims citations everywhere and reasoning where it applies' do
      expect(described_class.critical_capabilities_for('sonar')).to eq(%w[citations vision])
      expect(described_class.critical_capabilities_for('sonar-deep-research')).to eq(%w[citations reasoning])
      expect(described_class.critical_capabilities_for('pplx-embed-v1-0.6b')).to eq([])
    end
  end

  describe '.pricing_for' do
    it 'adds a reasoning tier for deep research' do
      expect(described_class.pricing_for('sonar-deep-research')).to eq(
        text_tokens: {
          standard: {
            input_per_million: 2.0,
            output_per_million: 8.0,
            reasoning_output_per_million: 3.0
          }
        }
      )
    end

    it 'falls back to the sonar rates for unknown models' do
      expect(described_class.pricing_for('sonar-experimental')).to eq(
        text_tokens: { standard: { input_per_million: 1.0, output_per_million: 1.0 } }
      )
    end

    it 'prices embedding models on input only' do
      expect(described_class.pricing_for('pplx-embed-v1-0.6b')).to eq(
        text_tokens: { standard: { input_per_million: 0.004 } }
      )
      expect(described_class.pricing_for('pplx-embed-v1-4b')).to eq(
        text_tokens: { standard: { input_per_million: 0.03 } }
      )
    end
  end
end
