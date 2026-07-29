# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::MiniMax do
  describe '#api_base' do
    it 'defaults to the global OpenAI-compatible endpoint' do
      RubyLLM.configure do |config|
        config.minimax_api_key = 'test'
        config.minimax_api_base = nil
      end
      provider = described_class.new(RubyLLM.config)

      expect(provider.api_base).to eq('https://api.minimax.io/v1')
    end

    it 'honors a configured regional endpoint' do
      RubyLLM.configure do |config|
        config.minimax_api_key = 'test'
        config.minimax_api_base = 'https://api.minimaxi.com/v1'
      end
      provider = described_class.new(RubyLLM.config)

      expect(provider.api_base).to eq('https://api.minimaxi.com/v1')
    end
  end

  describe '#headers' do
    it 'sends bearer authentication' do
      RubyLLM.configure { |config| config.minimax_api_key = 'secret-key' }
      provider = described_class.new(RubyLLM.config)

      expect(provider.headers).to eq({ 'Authorization' => 'Bearer secret-key' })
    end
  end

  describe 'registration' do
    it 'is registered under the :minimax slug' do
      expect(RubyLLM::Provider.providers[:minimax]).to eq(described_class)
      expect(described_class.slug).to eq('minimax')
    end

    it 'requires an API key' do
      expect(described_class.configuration_requirements).to eq(%i[minimax_api_key])
      expect(described_class.configuration_options).to eq(%i[minimax_api_key minimax_api_base])
    end
  end
end
