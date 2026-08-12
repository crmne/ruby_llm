# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ElevenLabs::Models do
  let(:capabilities) { RubyLLM::Providers::ElevenLabs::Capabilities }

  describe '.models_url' do
    it 'lists models rather than voices' do
      expect(described_class.models_url).to eq('v1/models')
    end
  end

  describe '.parse_list_models_response' do
    it 'reads the bare array ElevenLabs returns' do
      response = Struct.new(:body).new(
        [
          {
            'model_id' => 'eleven_v3',
            'name' => 'Eleven v3',
            'can_do_text_to_speech' => true,
            'description' => 'Our most emotionally rich model.'
          },
          {
            'model_id' => 'eleven_multilingual_sts_v2',
            'name' => 'Eleven Multilingual v2 (STS)',
            'can_do_voice_conversion' => true
          }
        ]
      )

      models = described_class.parse_list_models_response(response, 'elevenlabs', capabilities)
      speech = models.find { |model| model.id == 'eleven_v3' }
      conversion = models.find { |model| model.id == 'eleven_multilingual_sts_v2' }

      expect(speech.name).to eq('Eleven v3')
      expect(speech.provider).to eq('elevenlabs')
      expect(speech.family).to eq('eleven')
      expect(speech.modalities.to_h).to eq(input: ['text'], output: ['audio'])
      expect(speech.metadata).to eq(description: 'Our most emotionally rich model.')
      expect(conversion.modalities.to_h).to eq(input: ['audio'], output: ['audio'])
    end

    it 'appends the Scribe models the list endpoint leaves out' do
      response = Struct.new(:body).new([{ 'model_id' => 'eleven_v3', 'name' => 'Eleven v3' }])

      models = described_class.parse_list_models_response(response, 'elevenlabs', capabilities)
      scribe = models.find { |model| model.id == 'scribe_v2' }

      expect(scribe.name).to eq('Scribe v2')
      expect(scribe.capabilities).to eq(['transcription'])
      expect(scribe.modalities.to_h).to eq(input: ['audio'], output: ['text'])
    end

    it 'keeps the listed entry when the endpoint does return a Scribe model' do
      response = Struct.new(:body).new([{ 'model_id' => 'scribe_v2', 'name' => 'Scribe v2 (listed)' }])

      models = described_class.parse_list_models_response(response, 'elevenlabs', capabilities)

      expect(models.map(&:id)).to eq(['scribe_v2'])
      expect(models.first.name).to eq('Scribe v2 (listed)')
    end

    it 'falls back to a formatted name when the entry has none' do
      response = Struct.new(:body).new([{ 'model_id' => 'eleven_flash_v2_5' }])

      models = described_class.parse_list_models_response(response, 'elevenlabs', capabilities)

      expect(models.first.name).to eq('Eleven Flash V2 5')
    end
  end
end
