# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Deepgram::Capabilities do
  describe '.modalities_for' do
    it 'transcribes audio for the listening models' do
      expect(described_class.modalities_for('nova-3')).to eq(input: ['audio'], output: ['text'])
      expect(described_class.modalities_for('whisper-large')).to eq(input: ['audio'], output: ['text'])
      expect(described_class.modalities_for('flux-general-en')).to eq(input: ['audio'], output: ['text'])
    end

    it 'speaks text for the voice models' do
      expect(described_class.modalities_for('aura-2-thalia-en')).to eq(input: ['text'], output: ['audio'])
      expect(described_class.modalities_for('flux-alexis-en')).to eq(input: ['text'], output: ['audio'])
    end
  end

  describe '.capabilities_for' do
    it 'marks the listening models as transcription models' do
      expect(described_class.capabilities_for('nova-3')).to eq(['transcription'])
      expect(described_class.capabilities_for('whisper-medium')).to eq(['transcription'])
    end

    it 'claims nothing from the registry vocabulary for the voice models' do
      expect(described_class.capabilities_for('aura-2-thalia-en')).to eq([])
    end

    it 'claims nothing for Flux, which RubyLLM cannot reach over REST' do
      expect(described_class.capabilities_for('flux-general-en')).to eq([])
      expect(described_class.capabilities_for('flux-alexis-en')).to eq([])
    end
  end

  describe '.model_family' do
    it 'groups models by the generation they belong to' do
      expect(described_class.model_family('nova-2-phonecall')).to eq('nova')
      expect(described_class.model_family('whisper-large')).to eq('whisper')
      expect(described_class.model_family('aura-2-zeus-en')).to eq('aura')
      expect(described_class.model_family('flux-general-multi')).to eq('flux')
    end

    it 'falls back to the provider name for an unfamiliar id' do
      expect(described_class.model_family('something-else')).to eq('deepgram')
    end
  end

  describe '.format_display_name' do
    it 'titles the hyphenated model id and shouts the language code' do
      expect(described_class.format_display_name('nova-3-medical')).to eq('Nova 3 Medical')
      expect(described_class.format_display_name('aura-2-thalia-en')).to eq('Aura 2 Thalia EN')
    end
  end
end
