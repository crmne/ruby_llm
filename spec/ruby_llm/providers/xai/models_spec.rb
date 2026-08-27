# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::XAI::Models do
  describe '.parse_list_models_response' do
    it 'keeps only metadata the model list reports' do
      response = Struct.new(:body).new(
        {
          'data' => [
            {
              'id' => 'grok-4.3',
              'object' => 'model',
              'created' => 1_777_068_000,
              'owned_by' => 'xai'
            },
            {
              'id' => 'grok-4.20-0309-non-reasoning',
              'object' => 'model',
              'created' => 1_777_068_000,
              'owned_by' => 'xai'
            }
          ]
        }
      )

      models = described_class.parse_list_models_response(response, 'xai')
      reasoning_model = models.find { |model| model.id == 'grok-4.3' }
      non_reasoning_model = models.find { |model| model.id == 'grok-4.20-0309-non-reasoning' }

      expect(reasoning_model.name).to eq('grok-4.3')
      expect(reasoning_model.capabilities).to be_empty
      expect(reasoning_model.modalities.input).to be_empty
      expect(reasoning_model.modalities.output).to be_empty

      expect(non_reasoning_model.capabilities).to be_empty

      speech = models.find { |model| model.id == 'grok-tts' }
      expect(speech.family).to eq('grok')
    end

    it 'does not guess modalities from model ids' do
      response = Struct.new(:body).new(
        {
          'data' => [
            { 'id' => 'grok-imagine-image', 'object' => 'model', 'owned_by' => 'xai' },
            { 'id' => 'grok-imagine-video', 'object' => 'model', 'owned_by' => 'xai' }
          ]
        }
      )

      models = described_class.parse_list_models_response(response, 'xai')
      image_model = models.find { |model| model.id == 'grok-imagine-image' }
      video_model = models.find { |model| model.id == 'grok-imagine-video' }

      expect(image_model.modalities.to_h).to eq(input: [], output: [])
      expect(image_model.capabilities).to be_empty
      expect(video_model.modalities.to_h).to eq(input: [], output: [])
      expect(video_model.capabilities).to be_empty
    end
  end
end
