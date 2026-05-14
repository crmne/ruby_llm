# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Ollama do
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
      ollama_api_base: ollama_api_base,
      ollama_api_key: ollama_api_key
    )
  end

  let(:ollama_api_base) { 'http://localhost:11434' }
  let(:ollama_api_key) { nil }

  describe '#headers' do
    context 'when no API key is configured' do
      let(:ollama_api_key) { nil }

      it 'returns empty headers' do
        expect(provider.headers).to eq({})
      end
    end

    context 'when API key is configured' do
      let(:ollama_api_key) { 'test-ollama-key' }

      it 'returns Authorization header' do
        expect(provider.headers).to eq({ 'Authorization' => 'Bearer test-ollama-key' })
      end
    end
  end

  describe '#api_base' do
    context 'when base URL does not include /v1' do
      let(:ollama_api_base) { 'http://localhost:11434' }

      it 'appends /v1 for OpenAI-compatible endpoint' do
        expect(provider.api_base).to eq('http://localhost:11434/v1')
      end
    end

    context 'when base URL already includes /v1' do
      let(:ollama_api_base) { 'http://localhost:11434/v1' }

      it 'does not double-append /v1' do
        expect(provider.api_base).to eq('http://localhost:11434/v1')
      end
    end

    context 'when base URL has a trailing slash' do
      let(:ollama_api_base) { 'http://localhost:11434/' }

      it 'strips trailing slash and appends /v1' do
        expect(provider.api_base).to eq('http://localhost:11434/v1')
      end
    end

    context 'when base URL has /v1/ with trailing slash' do
      let(:ollama_api_base) { 'http://localhost:11434/v1/' }

      it 'normalizes to /v1 without trailing slash' do
        expect(provider.api_base).to eq('http://localhost:11434/v1')
      end
    end

    context 'when using a custom host and port' do
      let(:ollama_api_base) { 'https://my-ollama.com:8080' }

      it 'appends /v1 to the custom base' do
        expect(provider.api_base).to eq('https://my-ollama.com:8080/v1')
      end
    end
  end
end
