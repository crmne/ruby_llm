# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OllamaCloud do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    instance_double(
      RubyLLM::Configuration,
      request_timeout: 300,
      max_retries: 3,
      retry_interval: 0.1,
      retry_interval_randomness: 0.5,
      retry_backoff_factor: 2,
      http_proxy: nil,
      ollama_cloud_api_key: ollama_cloud_api_key,
      ollama_cloud_api_base: ollama_cloud_api_base
    )
  end

  let(:ollama_cloud_api_key) { 'test-cloud-key' }
  let(:ollama_cloud_api_base) { nil }

  describe '#api_base' do
    context 'when ollama_cloud_api_base is not set' do
      it 'returns the default Ollama Cloud URL' do
        expect(provider.api_base).to eq('https://ollama.com/v1')
      end
    end

    context 'when ollama_cloud_api_base is overridden' do
      let(:ollama_cloud_api_base) { 'https://proxy.example.com/v1' }

      it 'returns the custom API URL' do
        expect(provider.api_base).to eq('https://proxy.example.com/v1')
      end
    end
  end

  describe '#headers' do
    it 'sends Bearer auth with the configured key' do
      expect(provider.headers).to eq('Authorization' => 'Bearer test-cloud-key')
    end
  end

  describe 'class metadata' do
    it 'requires only ollama_cloud_api_key' do
      expect(described_class.configuration_requirements).to eq(%i[ollama_cloud_api_key])
    end

    it 'exposes both api_base and api_key as config options' do
      expect(described_class.configuration_options)
        .to contain_exactly(:ollama_cloud_api_base, :ollama_cloud_api_key)
    end

    it 'reports as a remote provider' do
      expect(described_class.local?).to be(false)
      expect(described_class.remote?).to be(true)
    end

    it 'uses the ollama_cloud slug (matches the registration symbol)' do
      expect(described_class.slug).to eq('ollama_cloud')
    end

    it 'assumes models exist so dynamic cloud models do not need registry entries' do
      expect(described_class.assume_models_exist?).to be(true)
    end
  end

  context 'when ollama_cloud_api_key is missing' do
    let(:ollama_cloud_api_key) { nil }

    it 'raises ConfigurationError on init' do
      expect { provider }.to raise_error(RubyLLM::ConfigurationError, /ollama_cloud_api_key/)
    end
  end
end
