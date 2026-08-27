# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Deepgram::Models do
  # Shaped after the models list response at
  # https://developers.deepgram.com/reference/manage/models/list
  let(:response) do
    Struct.new(:body).new(
      {
        'stt' => [
          {
            'name' => 'nova-3',
            'canonical_name' => 'nova-3',
            'architecture' => 'base',
            'languages' => %w[en en-us],
            'version' => '2021-11-10.1',
            'uuid' => '6b28e919-8427-4f32-9847-492e2efd7daf',
            'batch' => true,
            'streaming' => true,
            'formatted_output' => true
          }
        ],
        'tts' => [
          {
            'name' => 'zeus',
            'canonical_name' => 'aura-2-zeus-en',
            'architecture' => 'aura-2',
            'languages' => %w[en en-US],
            'version' => '2025-04-07.0',
            'uuid' => '2baf189d-91ac-481d-b6d1-750888667b31',
            'metadata' => {
              'accent' => 'American',
              'age' => 'Adult',
              'tags' => %w[masculine deep trustworthy smooth],
              'use_cases' => ['IVR']
            }
          }
        ]
      }
    )
  end

  describe '.models_url' do
    it 'lists the models Deepgram serves' do
      expect(described_class.models_url).to eq('v1/models')
    end
  end

  describe '.parse_list_models_response' do
    it 'reads both the stt and tts groups' do
      models = described_class.parse_list_models_response(response, 'deepgram')

      expect(models.map(&:id)).to eq(['nova-3', 'aura-2-zeus-en'])
    end

    it 'describes the listening models' do
      model = described_class.parse_list_models_response(response, 'deepgram').first

      expect(model.name).to eq('nova-3')
      expect(model.provider).to eq('deepgram')
      expect(model.family).to eq('base')
      expect(model.modalities.to_h).to eq(input: ['audio'], output: ['text'])
      expect(model.capabilities).to eq(['transcription'])
      expect(model.metadata).to include(architecture: 'base', languages: %w[en en-us], version: '2021-11-10.1')
    end

    it 'takes the callable canonical name as the id and keeps the voice name' do
      model = described_class.parse_list_models_response(response, 'deepgram').last

      expect(model.id).to eq('aura-2-zeus-en')
      expect(model.name).to eq('aura-2-zeus-en')
      expect(model.family).to eq('aura-2')
      expect(model.modalities.to_h).to eq(input: ['text'], output: ['audio'])
      expect(model.metadata).to include(voice: 'zeus', accent: 'American', use_cases: ['IVR'])
    end

    it 'survives a response with neither group' do
      expect(described_class.parse_list_models_response(Struct.new(:body).new({}), 'deepgram')).to eq([])
    end
  end
end
