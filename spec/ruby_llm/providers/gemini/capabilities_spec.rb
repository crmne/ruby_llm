# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Gemini::Capabilities do
  describe '.context_window_for' do
    {
      'gemini-2.5-pro-exp-03-25' => 1_048_576,
      'gemini-2.0-flash' => 1_048_576,
      'gemini-2.0-flash-lite' => 1_048_576,
      'gemini-1.5-flash' => 1_048_576,
      'gemini-1.5-flash-8b' => 1_048_576,
      'gemini-1.5-pro' => 2_097_152,
      'gemini-embedding-exp-03-07' => 8_192,
      'text-embedding-004' => 2_048,
      'embedding-001' => 2_048,
      'aqa' => 7_168,
      'imagen-3.0-generate-002' => nil,
      'gemini-3-flash-preview' => 32_768
    }.each do |model_id, expected|
      it "reports #{expected.inspect} for #{model_id}" do
        expect(described_class.context_window_for(model_id)).to eq(expected)
      end
    end
  end

  describe '.max_tokens_for' do
    {
      'gemini-2.5-pro-exp-03-25' => 64_000,
      'gemini-2.0-flash' => 8_192,
      'gemini-1.5-pro' => 8_192,
      'gemini-embedding-exp-03-07' => nil,
      'text-embedding-004' => 768,
      'embedding-001' => 768,
      'imagen-3.0-generate-002' => 4,
      'gemini-3-flash-preview' => 4_096
    }.each do |model_id, expected|
      it "reports #{expected.inspect} for #{model_id}" do
        expect(described_class.max_tokens_for(model_id)).to eq(expected)
      end
    end
  end

  describe '.supports?' do
    it 'excludes the embedding and attributed-QA models from vision' do
      expect(described_class.supports?('text-embedding-004', 'vision')).to be(false)
      expect(described_class.supports?('embedding-001', 'vision')).to be(false)
      expect(described_class.supports?('aqa', 'vision')).to be(false)
    end

    it 'includes the generative families in vision' do
      expect(described_class.supports?('gemini-2.5-flash', 'vision')).to be(true)
      expect(described_class.supports?('imagen-3.0-generate-002', 'vision')).to be(true)
    end

    it 'excludes embeddings, imagen and the lite tiers from function calling' do
      expect(described_class.supports?('text-embedding-004', 'function_calling')).to be(false)
      expect(described_class.supports?('aqa', 'function_calling')).to be(false)
      expect(described_class.supports?('imagen-3.0-generate-002', 'function_calling')).to be(false)
      expect(described_class.supports?('gemini-2.0-flash-lite', 'function_calling')).to be(false)
    end

    it 'includes the generative families in function calling' do
      expect(described_class.supports?('gemini-2.5-flash', 'function_calling')).to be(true)
    end

    it 'excludes embeddings, imagen, the lite tier and the 2.5 pro preview from structured output' do
      expect(described_class.supports?('embedding-001', 'structured_output')).to be(false)
      expect(described_class.supports?('imagen-3.0-generate-002', 'structured_output')).to be(false)
      expect(described_class.supports?('gemini-2.0-flash-lite', 'structured_output')).to be(false)
      expect(described_class.supports?('gemini-2.5-pro-exp-03-25', 'structured_output')).to be(false)
    end

    it 'includes the generative families in structured output' do
      expect(described_class.supports?('gemini-2.5-flash', 'structured_output')).to be(true)
    end
  end

  describe '.critical_capabilities_for' do
    it 'reports the full set for a generative model' do
      expect(described_class.critical_capabilities_for('gemini-2.5-flash')).to eq(
        %w[function_calling tool_choice structured_output vision]
      )
    end

    it 'reports nothing for an embedding model' do
      expect(described_class.critical_capabilities_for('text-embedding-004')).to eq([])
    end

    it 'reports only vision for the lite tier' do
      expect(described_class.critical_capabilities_for('gemini-2.0-flash-lite')).to eq(['vision'])
    end
  end

  describe '.pricing_family' do
    {
      'gemini-2.5-pro-exp-03-25' => :pro_2_5, # rubocop:disable Naming/VariableNumber
      'gemini-2.0-flash-lite' => :flash_lite_2, # rubocop:disable Naming/VariableNumber
      'gemini-2.0-flash' => :flash_2, # rubocop:disable Naming/VariableNumber
      'gemini-1.5-flash-8b' => :flash_8b,
      'gemini-1.5-flash' => :flash,
      'gemini-1.5-pro' => :pro,
      'gemini-embedding-exp-03-07' => :gemini_embedding,
      'text-embedding-004' => :embedding,
      'imagen-3.0-generate-002' => :imagen,
      'aqa' => :aqa,
      'gemini-3-flash-preview' => :base
    }.each do |model_id, expected|
      it "groups #{model_id} under #{expected}" do
        expect(described_class.pricing_family(model_id)).to eq(expected)
      end
    end
  end

  describe '.pricing_for' do
    it 'uses the family price table' do
      expect(described_class.pricing_for('gemini-2.0-flash')).to eq(
        text_tokens: { standard: { input_per_million: 0.10, output_per_million: 0.40 } }
      )
    end

    it 'spreads a single price across input and output' do
      expect(described_class.pricing_for('imagen-3.0-generate-002')).to eq(
        text_tokens: { standard: { input_per_million: 0.03, output_per_million: 0.03 } }
      )
    end

    it 'falls back to flash pricing for unknown families' do
      expect(described_class.pricing_for('gemini-3-flash-preview')).to eq(
        text_tokens: { standard: { input_per_million: 0.075, output_per_million: 0.30 } }
      )
    end
  end
end
