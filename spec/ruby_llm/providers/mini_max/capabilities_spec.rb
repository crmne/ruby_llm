# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::MiniMax::Capabilities do
  describe '.context_window_for' do
    it 'returns the documented context window per model' do
      expect(described_class.context_window_for('MiniMax-M3')).to eq(1_000_000)
      expect(described_class.context_window_for('MiniMax-M2.7')).to eq(204_800)
    end
  end

  describe '.critical_capabilities_for' do
    it 'marks MiniMax-M3 as a vision-capable reasoning model' do
      expect(described_class.critical_capabilities_for('MiniMax-M3')).to include('vision', 'reasoning')
    end

    it 'does not mark the text-only MiniMax-M2.7 as vision-capable' do
      expect(described_class.critical_capabilities_for('MiniMax-M2.7')).not_to include('vision')
    end
  end

  describe '.pricing_for' do
    it 'omits cache-write pricing when the model has none' do
      standard = described_class.pricing_for('MiniMax-M3').dig(:text_tokens, :standard)

      expect(standard).not_to have_key(:cache_write_input_per_million)
      expect(standard[:cache_read_input_per_million]).to eq(0.12)
    end

    it 'includes cache-write pricing when the model supports it' do
      standard = described_class.pricing_for('MiniMax-M2.7').dig(:text_tokens, :standard)

      expect(standard[:cache_write_input_per_million]).to eq(0.375)
    end
  end
end
