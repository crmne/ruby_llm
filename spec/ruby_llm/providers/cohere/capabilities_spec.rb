# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Cohere::Capabilities do
  describe '.capabilities_for' do
    it 'gives Command models tools, structured output, and citations' do
      expect(described_class.capabilities_for('command-a-03-2025'))
        .to contain_exactly('streaming', 'function_calling', 'tool_choice', 'structured_output', 'citations')
    end

    it 'marks the reasoning models' do
      expect(described_class.capabilities_for('command-a-reasoning-08-2025')).to include('reasoning')
      expect(described_class.capabilities_for('command-a-plus-05-2026')).to include('reasoning')
      expect(described_class.capabilities_for('command-a-03-2025')).not_to include('reasoning')
    end

    it 'marks the vision models' do
      expect(described_class.capabilities_for('command-a-vision-07-2025')).to include('vision')
      expect(described_class.capabilities_for('command-a-plus-05-2026')).to include('vision')
      expect(described_class.capabilities_for('command-r7b-12-2024')).not_to include('vision')
    end

    it 'leaves the Aya research models without tool support' do
      expect(described_class.capabilities_for('c4ai-aya-expanse-32b')).to eq(['streaming'])
    end

    it 'reports embedding and rerank models as having no chat capabilities' do
      expect(described_class.capabilities_for('embed-v4.0')).to be_empty
      expect(described_class.capabilities_for('rerank-v4.0-pro')).to be_empty
    end

    it 'marks the transcription model' do
      expect(described_class.capabilities_for('cohere-transcribe-03-2026')).to eq(['transcription'])
    end

    it 'classifies unknown models by the endpoints the catalog reports' do
      expect(described_class.capabilities_for('some-new-embedder', ['embed'])).to be_empty
    end
  end

  describe '.modalities_for' do
    it 'reports embeddings output for Embed models' do
      expect(described_class.modalities_for('embed-v4.0'))
        .to eq(input: %w[text image], output: ['embeddings'])
    end

    it 'reports rerank output for Rerank models' do
      expect(described_class.modalities_for('rerank-v3.5')).to eq(input: ['text'], output: ['rerank'])
    end

    it 'reports audio input for Cohere Transcribe' do
      expect(described_class.modalities_for('cohere-transcribe-03-2026')).to eq(input: ['audio'], output: ['text'])
    end

    it 'reports image input for vision models' do
      expect(described_class.modalities_for('command-a-vision-07-2025'))
        .to eq(input: %w[text image], output: ['text'])
    end
  end

  describe '.context_window_for and .max_tokens_for' do
    it 'reports the published limits' do
      expect(described_class.context_window_for('command-a-03-2025')).to eq(256_000)
      expect(described_class.max_tokens_for('command-a-03-2025')).to eq(8_000)
      expect(described_class.context_window_for('command-a-plus-05-2026')).to eq(128_000)
      expect(described_class.max_tokens_for('command-a-plus-05-2026')).to eq(64_000)
    end
  end

  describe '.pricing_for' do
    it 'prices Command models per million tokens' do
      expect(described_class.pricing_for('command-r7b-12-2024')).to eq(
        text_tokens: { standard: { input_per_million: 0.0375, output_per_million: 0.15 } }
      )
    end

    it 'leaves models Cohere does not publish token prices for unpriced' do
      expect(described_class.pricing_for('embed-v4.0')).to be_empty
    end
  end

  describe '.model_family' do
    it 'groups models by family' do
      expect(described_class.model_family('command-a-plus-05-2026')).to eq('command-a-plus')
      expect(described_class.model_family('command-a-vision-07-2025')).to eq('command-a')
      expect(described_class.model_family('command-r-plus-08-2024')).to eq('command-r-plus')
      expect(described_class.model_family('command-r-08-2024')).to eq('command-r')
      expect(described_class.model_family('command-r7b-12-2024')).to eq('command')
      expect(described_class.model_family('embed-v4.0')).to eq('embed')
      expect(described_class.model_family('rerank-v3.5')).to eq('rerank')
      expect(described_class.model_family('cohere-transcribe-03-2026')).to eq('transcribe')
      expect(described_class.model_family('c4ai-aya-vision-32b')).to eq('aya')
    end
  end
end
