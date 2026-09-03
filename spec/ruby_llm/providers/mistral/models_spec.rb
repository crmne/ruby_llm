# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Mistral::Models do
  subject(:model) { described_class.parse_list_models_response(response, 'mistral').first }

  let(:model_data) do
    {
      'id' => 'mistral-test',
      'object' => 'model',
      'owned_by' => 'mistralai',
      'description' => 'A test model',
      'max_context_length' => 262_144,
      'aliases' => ['mistral-test-latest'],
      'deprecation' => '2026-08-31T12:00:00Z',
      'deprecation_replacement_model' => 'mistral-medium-3-5',
      'capabilities' => {
        'completion_chat' => true,
        'function_calling' => true,
        'vision' => false,
        'audio_speech' => true
      }
    }
  end
  let(:response) { Struct.new(:body).new({ 'data' => [model_data] }) }

  describe '.parse_list_models_response' do
    it 'keeps the model identity from the provider' do
      expect(model.id).to eq('mistral-test')
      expect(model.name).to eq('mistral-test')
      expect(model.created_at).to be_nil
    end

    it 'takes the context window the listing reports' do
      expect(model.context_window).to eq(262_144)
      expect(model.max_output_tokens).to be_nil
    end

    it 'adds only capabilities the listing reports' do
      expect(model.capabilities).to contain_exactly('function_calling', 'speech_generation')
    end

    it 'gives image input to the models the listing marks as vision' do
      model_data['capabilities']['vision'] = true

      expect(model.modalities.input).to eq(%w[text image])
      expect(model.capabilities).to include('vision')
    end

    it 'recognizes an embedding operation from the provider description' do
      model_data['id'] = 'codestral-embed'
      model_data['description'] = 'Official Codestral embedding model'
      model_data['capabilities'] = { 'completion_chat' => false }

      expect(model.modalities.to_h).to eq(input: ['text'], output: ['embeddings'])
      expect(model.type).to eq(:embedding)
    end

    it 'keeps the deprecation, description and aliases in metadata' do
      expect(model.metadata).to include(
        description: 'A test model',
        aliases: ['mistral-test-latest'],
        deprecation: '2026-08-31T12:00:00Z',
        deprecation_replacement_model: 'mistral-medium-3-5'
      )
    end

    it 'does not invent metadata the listing omits' do
      model_data.delete('max_context_length')
      model_data.delete('capabilities')
      model_data.delete('deprecation')
      model_data['aliases'] = []

      expect(model.context_window).to be_nil
      expect(model.capabilities).to be_empty
      expect(model.pricing.to_h).to be_empty
      expect(model.metadata.keys).not_to include(:deprecation, :aliases)
    end
  end
end
