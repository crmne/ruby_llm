# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::MiniMax::Capabilities do
  describe '.context_window_for' do
    it 'returns 1_000_000 for M2.7 models' do
      expect(described_class.context_window_for('MiniMax-M2.7')).to eq(1_000_000)
    end

    it 'returns 1_000_000 for M2.7-highspeed models' do
      expect(described_class.context_window_for('MiniMax-M2.7-highspeed')).to eq(1_000_000)
    end

    it 'returns 204_000 for M2.5 models' do
      expect(described_class.context_window_for('MiniMax-M2.5')).to eq(204_000)
    end

    it 'returns 204_000 for M2.5-highspeed models' do
      expect(described_class.context_window_for('MiniMax-M2.5-highspeed')).to eq(204_000)
    end
  end

  describe '.max_tokens_for' do
    it 'returns 16_384 for M2.7 models' do
      expect(described_class.max_tokens_for('MiniMax-M2.7')).to eq(16_384)
    end

    it 'returns 16_384 for M2.5 models' do
      expect(described_class.max_tokens_for('MiniMax-M2.5')).to eq(16_384)
    end
  end

  describe '.model_family' do
    it 'returns :m2_7 for M2.7' do
      expect(described_class.model_family('MiniMax-M2.7')).to eq(:m2_7)
    end

    it 'returns :m2_7_highspeed for M2.7-highspeed' do
      expect(described_class.model_family('MiniMax-M2.7-highspeed')).to eq(:m2_7_highspeed)
    end

    it 'returns :m2_5 for M2.5' do
      expect(described_class.model_family('MiniMax-M2.5')).to eq(:m2_5)
    end

    it 'returns :m2_5_highspeed for M2.5-highspeed' do
      expect(described_class.model_family('MiniMax-M2.5-highspeed')).to eq(:m2_5_highspeed)
    end
  end

  describe '.supports_functions?' do
    it 'returns true for M2.7 models' do
      expect(described_class.supports_functions?('MiniMax-M2.7')).to be true
    end

    it 'returns true for M2.5 models' do
      expect(described_class.supports_functions?('MiniMax-M2.5')).to be true
    end
  end

  describe '.supports_json_mode?' do
    it 'returns true for M2.7 models' do
      expect(described_class.supports_json_mode?('MiniMax-M2.7')).to be true
    end

    it 'returns true for M2.5 models' do
      expect(described_class.supports_json_mode?('MiniMax-M2.5')).to be true
    end
  end

  describe '.supports_vision?' do
    it 'returns false for all models' do
      expect(described_class.supports_vision?('MiniMax-M2.7')).to be false
    end
  end

  describe '.model_type' do
    it 'returns chat for all models' do
      expect(described_class.model_type('MiniMax-M2.7')).to eq('chat')
    end
  end

  describe '.format_display_name' do
    it 'returns the model id as-is' do
      expect(described_class.format_display_name('MiniMax-M2.7')).to eq('MiniMax-M2.7')
    end
  end

  describe '.capabilities_for' do
    it 'includes streaming for all models' do
      expect(described_class.capabilities_for('MiniMax-M2.7')).to include('streaming')
    end

    it 'includes function_calling for M2.7' do
      expect(described_class.capabilities_for('MiniMax-M2.7')).to include('function_calling')
    end

    it 'includes json_mode for M2.7' do
      expect(described_class.capabilities_for('MiniMax-M2.7')).to include('json_mode')
    end
  end

  describe '.pricing_for' do
    it 'returns pricing hash for M2.7' do
      pricing = described_class.pricing_for('MiniMax-M2.7')
      expect(pricing).to have_key(:text_tokens)
      expect(pricing[:text_tokens][:standard]).to include(:input_per_million, :output_per_million)
    end
  end

  describe '.modalities_for' do
    it 'returns text input and output' do
      modalities = described_class.modalities_for('MiniMax-M2.7')
      expect(modalities[:input]).to eq(['text'])
      expect(modalities[:output]).to eq(['text'])
    end
  end
end
