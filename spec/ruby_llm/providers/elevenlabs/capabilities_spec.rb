# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::ElevenLabs::Capabilities do
  describe '.modalities_for' do
    it 'speaks text for the synthesis models' do
      expect(described_class.modalities_for('eleven_v3')).to eq(input: ['text'], output: ['audio'])
    end

    it 'transcribes audio for the Scribe models' do
      expect(described_class.modalities_for('scribe_v2')).to eq(input: ['audio'], output: ['text'])
    end

    it 'converts audio to audio for the speech-to-speech models' do
      expect(described_class.modalities_for('eleven_multilingual_sts_v2')).to eq(input: ['audio'], output: ['audio'])
    end
  end

  describe '.capabilities_for' do
    it 'marks Scribe models as transcription models' do
      expect(described_class.capabilities_for('scribe_v2')).to eq(['transcription'])
    end

    it 'claims nothing from the registry vocabulary for synthesis models' do
      expect(described_class.capabilities_for('eleven_v3')).to eq([])
    end
  end

  describe '.model_family' do
    it 'groups models by the product they belong to' do
      expect(described_class.model_family('eleven_flash_v2_5')).to eq('eleven')
      expect(described_class.model_family('scribe_v2')).to eq('scribe')
      expect(described_class.model_family('music_v2')).to eq('music')
    end
  end

  describe '.format_display_name' do
    it 'titles the underscored model id' do
      expect(described_class.format_display_name('eleven_flash_v2_5')).to eq('Eleven Flash V2 5')
    end
  end
end
