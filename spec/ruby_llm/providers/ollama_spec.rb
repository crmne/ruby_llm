# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Ollama do
  include_context 'with configured RubyLLM'

  describe '#headers' do
    it 'returns empty headers when no API key is configured' do
      RubyLLM.configure { |config| config.ollama_api_key = nil }
      provider = described_class.new(RubyLLM.config)

      expect(provider.headers).to eq({})
    end

    it 'returns Authorization header when API key is configured' do
      RubyLLM.configure { |config| config.ollama_api_key = 'test-ollama-key' }
      provider = described_class.new(RubyLLM.config)

      expect(provider.headers).to eq({ 'Authorization' => 'Bearer test-ollama-key' })
    end
  end
end
