# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::MiniMax::Models do
  include_context 'with configured RubyLLM'

  let(:provider) { RubyLLM::Providers::MiniMax.new(RubyLLM.config) }

  describe '#list_models' do
    it 'returns statically defined MiniMax models' do
      models = provider.list_models
      model_ids = models.map(&:id)

      expect(model_ids).to include('MiniMax-M2.7', 'MiniMax-M2.7-highspeed',
                                   'MiniMax-M2.5', 'MiniMax-M2.5-highspeed')
    end

    it 'returns 4 models' do
      expect(provider.list_models.size).to eq(4)
    end

    it 'sets the provider slug to minimax' do
      models = provider.list_models
      expect(models).to all(have_attributes(provider: 'minimax'))
    end

    it 'sets correct context window for M2.7' do
      models = provider.list_models
      m27 = models.find { |m| m.id == 'MiniMax-M2.7' }
      expect(m27.context_window).to eq(1_000_000)
    end

    it 'sets correct context window for M2.5-highspeed' do
      models = provider.list_models
      m25hs = models.find { |m| m.id == 'MiniMax-M2.5-highspeed' }
      expect(m25hs.context_window).to eq(204_000)
    end
  end
end
