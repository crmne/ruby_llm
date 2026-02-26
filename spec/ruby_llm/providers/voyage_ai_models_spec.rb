# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VoyageAI do
  describe '#list_models' do
    it 'returns the MongoDB-documented Voyage model catalog' do
      config = RubyLLM::Configuration.new
      config.voyage_api_key = 'test'
      provider = described_class.new(config)

      models = provider.list_models
      ids = models.map(&:id)

      expect(ids).to include(
        'voyage-4-large',
        'voyage-context-3',
        'voyage-multimodal-3.5',
        'rerank-2.5'
      )
    end

    it 'sets rerank models to rerank type instead of chat' do
      config = RubyLLM::Configuration.new
      config.voyage_api_key = 'test'
      provider = described_class.new(config)

      rerank_model = provider.list_models.find { |m| m.id == 'rerank-2.5' }

      expect(rerank_model).not_to be_nil
      expect(rerank_model.type).to eq('rerank')
      expect(rerank_model.modalities.output).to include('rerank')
    end
  end
end
