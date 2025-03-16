# frozen_string_literal: true

require 'spec_helper'
require 'dotenv/load'

RSpec.describe RubyLLM::Providers::OpenRouter::Models do
  include_context 'with configured RubyLLM'

  before do
    RubyLLM.configure do |config|
      config.open_router_api_key = ENV.fetch('OPENROUTER_API_KEY')
    end
  end

  describe 'model listing' do
    let(:models) { described_class.list_models }

    it 'returns a list of models' do
      expect(models).not_to be_empty
      expect(models).to all(be_a(RubyLLM::ModelInfo))
    end

    it 'includes required model information' do
      model = models.first
      expect(model.id).to be_a(String)
      expect(model.name).to be_a(String)
      expect(model.provider).to eq('open_router')
      expect(model.context_window).to be_a(Integer)
    end

    it 'includes pricing information' do
      model = models.first
      expect(model.pricing).to include(:input, :output)
      expect(model.pricing[:input]).to be_a(Numeric)
      expect(model.pricing[:output]).to be_a(Numeric)
    end
  end

  describe 'model capabilities' do
    let(:models) { described_class.list_models }

    it 'correctly identifies chat models' do
      chat_models = models.select { |m| m.capabilities[:chat] }
      expect(chat_models).not_to be_empty
      expect(chat_models).to all(have_attributes(capabilities: include(chat: true)))
    end

    it 'correctly identifies embedding models' do
      embedding_models = models.select { |m| m.capabilities[:embeddings] }
      expect(embedding_models).to all(have_attributes(capabilities: include(embeddings: true)))
    end

    it 'correctly identifies streaming support' do
      streaming_models = models.select { |m| m.capabilities[:streaming] }
      expect(streaming_models).not_to be_empty
      expect(streaming_models).to all(have_attributes(capabilities: include(streaming: true)))
    end

    it 'correctly identifies tool support' do
      tool_models = models.select { |m| m.capabilities[:tools] }
      expect(tool_models).to all(have_attributes(capabilities: include(tools: true)))
    end
  end

  describe 'model translation' do
    it 'preserves provider/model format' do
      model_id = 'anthropic/claude-3-opus-20240229'
      expect(described_class.translate_model_id(model_id)).to eq(model_id)
    end
  end

  describe 'response parsing' do
    it 'handles empty responses' do
      response = double('response', body: '')
      expect(described_class.parse_models_response(response)).to eq([])
    end

    it 'parses model data correctly' do
      response = double('response', body: {
        'data' => [{
          'id' => 'test-model',
          'name' => 'Test Model',
          'context_length' => 8192,
          'pricing' => {
            'input' => 0.0001,
            'output' => 0.0002
          },
          'type' => 'chat',
          'supports_tools' => true
        }]
      })

      models = described_class.parse_models_response(response)
      expect(models.length).to eq(1)
      model = models.first

      expect(model.id).to eq('test-model')
      expect(model.name).to eq('Test Model')
      expect(model.context_window).to eq(8192)
      expect(model.pricing[:input]).to eq(0.0001)
      expect(model.pricing[:output]).to eq(0.0002)
      expect(model.capabilities[:chat]).to be true
      expect(model.capabilities[:tools]).to be true
    end
  end
end 