# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::XAI::Models do
  describe '.parse_list_models_response' do
    it 'keeps only provider-owned fallback capabilities for Grok chat models' do
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

      models = described_class.parse_list_models_response(response, 'xai', nil)
      reasoning_model = models.find { |model| model.id == 'grok-4.3' }
      non_reasoning_model = models.find { |model| model.id == 'grok-4.20-0309-non-reasoning' }

      expect(reasoning_model.capabilities).to eq(['streaming'])
      expect(reasoning_model.modalities.input).to eq(['text'])
      expect(reasoning_model.modalities.output).to eq(['text'])

      expect(non_reasoning_model.capabilities).to eq(['streaming'])
    end

    it 'marks Grok imagine models using modality patterns' do
      response = Struct.new(:body).new(
        {
          'data' => [
            { 'id' => 'grok-imagine-image', 'object' => 'model', 'owned_by' => 'xai' },
            { 'id' => 'grok-imagine-video', 'object' => 'model', 'owned_by' => 'xai' }
          ]
        }
      )

      models = described_class.parse_list_models_response(response, 'xai', nil)
      image_model = models.find { |model| model.id == 'grok-imagine-image' }
      video_model = models.find { |model| model.id == 'grok-imagine-video' }

      expect(image_model.modalities.to_h).to eq(input: %w[text image], output: ['image'])
      expect(image_model.capabilities).to eq(['vision'])
      expect(video_model.modalities.to_h).to eq(input: %w[text image video], output: ['video'])
      expect(video_model.capabilities).to eq(['vision'])
    end
  end
end
