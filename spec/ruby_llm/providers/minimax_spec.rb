# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::MiniMax do
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
      minimax_api_key: 'test-key',
      minimax_api_base: minimax_api_base
    )
  end

  describe '#api_base' do
    context 'when minimax_api_base is not set' do
      let(:minimax_api_base) { nil }

      it 'returns the default MiniMax API URL' do
        expect(provider.api_base).to eq('https://api.minimax.io/v1')
      end
    end

    context 'when minimax_api_base is set' do
      let(:minimax_api_base) { 'https://custom-minimax-endpoint.example.com' }

      it 'returns the custom API URL' do
        expect(provider.api_base).to eq('https://custom-minimax-endpoint.example.com')
      end
    end
  end

  describe '#headers' do
    let(:minimax_api_base) { nil }

    it 'returns Authorization header with API key' do
      expect(provider.headers).to include('Authorization' => 'Bearer test-key')
    end

    it 'returns Content-Type header' do
      expect(provider.headers).to include('Content-Type' => 'application/json')
    end
  end

  describe '.configuration_options' do
    it 'includes minimax_api_key and minimax_api_base' do
      expect(described_class.configuration_options).to contain_exactly(:minimax_api_key, :minimax_api_base)
    end
  end

  describe '.configuration_requirements' do
    it 'requires minimax_api_key' do
      expect(described_class.configuration_requirements).to contain_exactly(:minimax_api_key)
    end
  end

  describe '.capabilities' do
    it 'returns MiniMax::Capabilities module' do
      expect(described_class.capabilities).to eq(RubyLLM::Providers::MiniMax::Capabilities)
    end
  end

  describe '.slug' do
    it 'returns minimax' do
      expect(described_class.slug).to eq('minimax')
    end
  end
end
