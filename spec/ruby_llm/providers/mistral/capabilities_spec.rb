# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Mistral::Capabilities do
  describe '.supports?' do
    it 'excludes the non-conversational endpoints from streaming' do
      expect(described_class.supports?('mistral-small-latest', 'streaming')).to be(true)
      expect(described_class.supports?('mistral-embed', 'streaming')).to be(false)
      expect(described_class.supports?('mistral-moderation-latest', 'streaming')).to be(false)
      expect(described_class.supports?('mistral-ocr-latest', 'streaming')).to be(false)
      expect(described_class.supports?('voxtral-mini-transcriptions', 'streaming')).to be(false)
    end

    it 'excludes embeddings, audio and the retired tiny/small snapshots from tool use' do
      expect(described_class.supports?('mistral-large-latest', 'function_calling')).to be(true)
      expect(described_class.supports?('mistral-embed', 'function_calling')).to be(false)
      expect(described_class.supports?('voxtral-small-latest', 'function_calling')).to be(false)
      expect(described_class.supports?('mistral-tiny-2312', 'function_calling')).to be(false)
      expect(described_class.supports?('mistral-small-2402', 'function_calling')).to be(false)
    end

    it 'recognizes the multimodal families' do
      expect(described_class.supports?('pixtral-12b-latest', 'vision')).to be(true)
      expect(described_class.supports?('mistral-small-2503', 'vision')).to be(true)
      expect(described_class.supports?('mistral-small-2506', 'vision')).to be(true)
      expect(described_class.supports?('mistral-medium-latest', 'vision')).to be(true)
      expect(described_class.supports?('mistral-large-latest', 'vision')).to be(false)
    end

    it 'requires tool support on top of a conversational model for structured output' do
      expect(described_class.supports?('mistral-small-latest', 'structured_output')).to be(true)
      expect(described_class.supports?('mistral-embed', 'structured_output')).to be(false)
      expect(described_class.supports?('mistral-tiny-2312', 'structured_output')).to be(false)
    end

    it 'recognizes native and adjustable reasoning models' do
      expect(described_class.supports?('magistral-small-latest', 'reasoning')).to be(true)
      expect(described_class.supports?('mistral-small-latest', 'reasoning')).to be(true)
      expect(described_class.supports?('mistral-medium-3-5', 'reasoning')).to be(true)
      expect(described_class.supports?('mistral-medium-3.5', 'reasoning')).to be(true)
      expect(described_class.supports?('pixtral-12b', 'reasoning')).to be(false)
    end
  end

  describe '.format_display_name' do
    {
      'mistral-large-latest' => 'Mistral Large',
      'mistral-medium-latest' => 'Mistral Medium',
      'mistral-small-latest' => 'Mistral Small',
      'ministral-3b-latest' => 'Ministral 3B',
      'ministral-8b-latest' => 'Ministral 8B',
      'codestral-latest' => 'Codestral',
      'pixtral-large-latest' => 'Pixtral Large',
      'pixtral-12b-2409' => 'Pixtral 12B',
      'mistral-embed' => 'Mistral Embed',
      'mistral-moderation-latest' => 'Mistral Moderation',
      'open-mixtral-8x7b' => 'Open Mixtral 8x7b'
    }.each do |model_id, expected|
      it "names #{model_id} #{expected}" do
        expect(described_class.format_display_name(model_id)).to eq(expected)
      end
    end
  end

  describe '.model_family' do
    {
      'mistral-large-latest' => 'mistral-large',
      'mistral-medium-latest' => 'mistral-medium',
      'mistral-small-latest' => 'mistral-small',
      'ministral-8b-latest' => 'ministral',
      'codestral-latest' => 'codestral',
      'pixtral-12b-2409' => 'pixtral',
      'mistral-embed' => 'mistral-embed',
      'mistral-moderation-latest' => 'mistral-moderation',
      'magistral-medium-latest' => 'mistral'
    }.each do |model_id, expected|
      it "groups #{model_id} under #{expected}" do
        expect(described_class.model_family(model_id)).to eq(expected)
      end
    end
  end

  describe '.context_window_for and .max_tokens_for' do
    it 'falls back to the documented defaults' do
      expect(described_class.context_window_for('mistral-small-latest')).to eq(32_768)
      expect(described_class.max_tokens_for('mistral-small-latest')).to eq(8192)
    end
  end

  describe '.modalities_for' do
    it 'gives pixtral image input' do
      expect(described_class.modalities_for('pixtral-12b-2409')).to eq(
        input: %w[text image], output: ['text']
      )
    end

    it 'gives embedding models an embeddings output' do
      expect(described_class.modalities_for('mistral-embed')).to eq(
        input: ['text'], output: ['embeddings']
      )
    end

    it 'gives voxtral chat models audio input' do
      expect(described_class.modalities_for('voxtral-small-latest')).to eq(
        input: %w[text audio], output: ['text']
      )
    end

    it 'gives voxtral transcribe models audio in, text out' do
      expect(described_class.modalities_for('voxtral-mini-transcribe-realtime-2602')).to eq(
        input: ['audio'], output: ['text']
      )
    end

    it 'gives voxtral tts models an audio output' do
      expect(described_class.modalities_for('voxtral-mini-tts-latest')).to eq(
        input: ['text'], output: ['audio']
      )
    end

    it 'defaults to text in, text out' do
      expect(described_class.modalities_for('mistral-large-latest')).to eq(
        input: ['text'], output: ['text']
      )
    end

    it 'stays fast on a model id that repeats voxtral' do
      model_id = "#{'voxtral' * 50_000}-nope"

      expect { Timeout.timeout(5) { described_class.modalities_for(model_id) } }.not_to raise_error
    end
  end

  describe '.capabilities_for' do
    it 'returns a single capability for the specialized endpoints' do
      expect(described_class.capabilities_for('mistral-moderation-latest')).to eq(['moderation'])
      expect(described_class.capabilities_for('voxtral-mini-transcribe')).to eq(['transcription'])
      expect(described_class.capabilities_for('mistral-ocr-latest')).to eq(['vision'])
    end

    it 'builds the conversational capability set' do
      expect(described_class.capabilities_for('mistral-small-latest')).to contain_exactly(
        'streaming', 'function_calling', 'tool_choice', 'parallel_tool_calls', 'structured_output',
        'reasoning', 'batch', 'fine_tuning'
      )
    end

    it 'adds vision for the multimodal families' do
      expect(described_class.capabilities_for('pixtral-12b-2409')).to include('vision')
    end

    it 'adds distillation for ministral and predicted outputs for codestral' do
      expect(described_class.capabilities_for('ministral-8b-latest')).to include('distillation')
      expect(described_class.capabilities_for('codestral-latest')).to include('predicted_outputs')
    end

    it 'omits batch for embedding models' do
      expect(described_class.capabilities_for('mistral-embed')).not_to include('batch')
    end
  end

  describe '.pricing_for' do
    it 'returns zeroed pricing so the registry keeps models.dev numbers' do
      expect(described_class.pricing_for('mistral-small-latest')).to eq(input: 0.0, output: 0.0)
    end
  end

  describe '.release_date_for' do
    {
      'open-mistral-7b' => '2023-09-27',
      'mistral-tiny' => '2023-09-27',
      'mistral-medium-2312' => '2023-12-11',
      'mistral-small-2312' => '2023-12-11',
      'mistral-small' => '2023-12-11',
      'open-mixtral-8x7b' => '2023-12-11',
      'mistral-tiny-2312' => '2023-12-11',
      'mistral-embed' => '2024-01-11',
      'mistral-large-2402' => '2024-02-26',
      'mistral-small-2402' => '2024-02-26',
      'open-mixtral-8x22b' => '2024-04-17',
      'open-mixtral-8x22b-2404' => '2024-04-17',
      'codestral-2405' => '2024-05-22',
      'codestral-mamba-2407' => '2024-07-16',
      'codestral-mamba-latest' => '2024-07-16',
      'open-codestral-mamba' => '2024-07-16',
      'open-mistral-nemo' => '2024-07-18',
      'open-mistral-nemo-2407' => '2024-07-18',
      'mistral-tiny-2407' => '2024-07-18',
      'mistral-tiny-latest' => '2024-07-18',
      'mistral-large-2407' => '2024-07-24',
      'pixtral-12b-2409' => '2024-09-17',
      'pixtral-12b-latest' => '2024-09-17',
      'pixtral-12b' => '2024-09-17',
      'mistral-small-2409' => '2024-09-18',
      'ministral-3b-2410' => '2024-10-16',
      'ministral-3b-latest' => '2024-10-16',
      'ministral-8b-2410' => '2024-10-16',
      'ministral-8b-latest' => '2024-10-16',
      'pixtral-large-2411' => '2024-11-12',
      'pixtral-large-latest' => '2024-11-12',
      'mistral-large-pixtral-2411' => '2024-11-12',
      'mistral-large-2411' => '2024-11-20',
      'mistral-large-latest' => '2024-11-20',
      'mistral-large' => '2024-11-20',
      'codestral-2411-rc5' => '2024-11-26',
      'mistral-moderation-2411' => '2024-11-26',
      'mistral-moderation-latest' => '2024-11-26',
      'codestral-2412' => '2024-12-17',
      'mistral-small-2501' => '2025-01-13',
      'codestral-2501' => '2025-01-14',
      'mistral-saba-2502' => '2025-02-18',
      'mistral-saba-latest' => '2025-02-18',
      'mistral-small-2503' => '2025-03-03',
      'mistral-ocr-2503' => '2025-03-21',
      'mistral-medium' => '2025-05-06',
      'mistral-medium-latest' => '2025-05-06',
      'mistral-medium-2505' => '2025-05-06',
      'codestral-embed' => '2025-05-21',
      'codestral-embed-2505' => '2025-05-21',
      'mistral-ocr-2505' => '2025-05-23',
      'mistral-ocr-latest' => '2025-05-23',
      'devstral-small-2505' => '2025-05-28',
      'mistral-small-2506' => '2025-06-10',
      'mistral-small-latest' => '2025-06-10',
      'magistral-medium-2506' => '2025-06-10',
      'magistral-medium-latest' => '2025-06-10',
      'devstral-small-2507' => '2025-07-09',
      'devstral-small-latest' => '2025-07-09',
      'devstral-medium-2507' => '2025-07-09',
      'devstral-medium-latest' => '2025-07-09',
      'codestral-2508' => '2025-08-30',
      'codestral-latest' => '2025-08-30'
    }.each do |model_id, expected|
      it "dates #{model_id} to #{expected}" do
        expect(described_class.release_date_for(model_id)).to eq(expected)
      end
    end

    it 'returns nil for unknown snapshots' do
      expect(described_class.release_date_for('mistral-unreleased-9999')).to be_nil
    end
  end
end
