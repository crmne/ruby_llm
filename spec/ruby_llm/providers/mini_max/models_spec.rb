# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::MiniMax::Models do
  describe '#list_models' do
    let(:provider_class) do
      Class.new do
        include RubyLLM::Providers::MiniMax::Models
      end
    end

    it 'returns the curated MiniMax catalog with fallback metadata' do
      models = provider_class.new.list_models

      expect(models.map(&:id)).to eq(%w[MiniMax-M3 MiniMax-M2.7])
      expect(models).to all(have_attributes(provider: 'minimax', family: 'minimax'))
    end

    it 'describes MiniMax-M3 with multimodal input and cache-read pricing' do
      model = provider_class.new.list_models.find { |m| m.id == 'MiniMax-M3' }

      expect(model.context_window).to eq(1_000_000)
      expect(model.modalities.input).to eq(%w[text image video])
      expect(model.modalities.output).to eq(%w[text])
      expect(model.capabilities).to contain_exactly('function_calling', 'tool_choice', 'reasoning', 'vision')
      expect(model.pricing.to_h).to eq(
        text_tokens: {
          standard: {
            input_per_million: 0.6,
            output_per_million: 2.4,
            cache_read_input_per_million: 0.12
          }
        }
      )
    end

    it 'describes MiniMax-M2.7 as a text reasoning model with cache pricing' do
      model = provider_class.new.list_models.find { |m| m.id == 'MiniMax-M2.7' }

      expect(model.context_window).to eq(204_800)
      expect(model.modalities.input).to eq(%w[text])
      expect(model.capabilities).to contain_exactly('function_calling', 'tool_choice', 'reasoning')
      expect(model.capabilities).not_to include('vision')
      expect(model.pricing.to_h).to eq(
        text_tokens: {
          standard: {
            input_per_million: 0.3,
            output_per_million: 1.2,
            cache_read_input_per_million: 0.06,
            cache_write_input_per_million: 0.375
          }
        }
      )
    end
  end
end
