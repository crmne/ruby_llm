# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::RedCandle::Capabilities do
  describe 'feature support' do
    it 'does not support vision' do
      expect(described_class.supports_vision?).to be false
    end

    it 'does not support functions' do
      expect(described_class.supports_functions?).to be false
    end

    it 'supports streaming' do
      expect(described_class.supports_streaming?).to be true
    end

    it 'supports structured output' do
      expect(described_class.supports_structured_output?).to be true
    end

    it 'supports regex constraints' do
      expect(described_class.supports_regex_constraints?).to be true
    end

    it 'does not support embeddings yet' do
      expect(described_class.supports_embeddings?).to be false
    end

    it 'does not support audio' do
      expect(described_class.supports_audio?).to be false
    end

    it 'does not support PDF' do
      expect(described_class.supports_pdf?).to be false
    end
  end

  describe '#normalize_temperature' do
    it 'returns default temperature when nil' do
      expect(described_class.normalize_temperature(nil, 'any_model')).to eq(0.7)
    end

    it 'clamps temperature to valid range' do
      expect(described_class.normalize_temperature(-1, 'any_model')).to eq(0.0)
      expect(described_class.normalize_temperature(3, 'any_model')).to eq(2.0)
      expect(described_class.normalize_temperature(1.5, 'any_model')).to eq(1.5)
    end
  end

  describe '#model_context_window' do
    it 'returns correct context window for known models' do
      expect(described_class.model_context_window('google/gemma-3-4b-it-qat-q4_0-gguf')).to eq(8192)
      expect(described_class.model_context_window('TheBloke/Mistral-7B-Instruct-v0.2-GGUF')).to eq(32_768)
      expect(described_class.model_context_window('TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF')).to eq(2048)
    end

    it 'returns default for unknown models' do
      expect(described_class.model_context_window('unknown/model')).to eq(4096)
    end
  end

  describe '#pricing' do
    it 'returns infinite tokens per dollar for local execution' do
      pricing = described_class.pricing
      expect(pricing[:input_tokens_per_dollar]).to eq(Float::INFINITY)
      expect(pricing[:output_tokens_per_dollar]).to eq(Float::INFINITY)
      expect(pricing[:input_price_per_million_tokens]).to eq(0.0)
      expect(pricing[:output_price_per_million_tokens]).to eq(0.0)
    end
  end

  describe 'generation parameters' do
    it 'provides correct defaults and limits' do
      expect(described_class.default_max_tokens).to eq(512)
      expect(described_class.max_temperature).to eq(2.0)
      expect(described_class.min_temperature).to eq(0.0)
    end

    it 'supports various generation parameters' do
      expect(described_class.supports_temperature?).to be true
      expect(described_class.supports_top_p?).to be true
      expect(described_class.supports_top_k?).to be true
      expect(described_class.supports_repetition_penalty?).to be true
      expect(described_class.supports_seed?).to be true
      expect(described_class.supports_stop_sequences?).to be true
    end
  end

  describe '#model_families' do
    it 'returns supported model families' do
      expect(described_class.model_families).to eq(%w[gemma llama qwen2 mistral phi])
    end
  end

  describe '#available_on_platform?' do
    context 'when Candle is available' do
      before do
        allow(described_class).to receive(:require).with('candle').and_return(true)
      end

      it 'returns true' do
        expect(described_class.available_on_platform?).to be true
      end
    end

    context 'when Candle is not available' do
      before do
        allow(described_class).to receive(:require).with('candle').and_raise(LoadError)
      end

      it 'returns false' do
        expect(described_class.available_on_platform?).to be false
      end
    end
  end
end
