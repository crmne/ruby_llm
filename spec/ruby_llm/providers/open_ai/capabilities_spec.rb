# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Capabilities do
  describe '.model_family' do
    {
      'gpt-5' => 'gpt5',
      'gpt-5-2025-06-01' => 'gpt5',
      'gpt-5.4' => 'gpt5',
      'gpt-5-mini' => 'gpt5_mini',
      'gpt-5.4-mini' => 'gpt5_mini',
      'gpt-5-nano' => 'gpt5_nano',
      'gpt-5-nano-2025-08-07' => 'gpt5_nano',
      'gpt-5.4-nano' => 'gpt5_nano',
      'gpt-5.4-nano-2026-03-17' => 'gpt5_nano'
    }.each do |model_id, expected_family|
      it "classifies #{model_id} as #{expected_family}" do
        expect(described_class.model_family(model_id)).to eq(expected_family)
      end
    end
  end

  describe '.pricing_for' do
    it 'returns gpt5_nano pricing for gpt-5.4-nano' do
      pricing = described_class.pricing_for('gpt-5.4-nano')
      standard = pricing[:text_tokens][:standard]

      expect(standard[:input_per_million]).to eq(0.05)
      expect(standard[:output_per_million]).to eq(0.4)
    end

    it 'returns gpt5 pricing for gpt-5.4' do
      pricing = described_class.pricing_for('gpt-5.4')
      standard = pricing[:text_tokens][:standard]

      expect(standard[:input_per_million]).to eq(1.25)
      expect(standard[:output_per_million]).to eq(10.0)
    end
  end
end
