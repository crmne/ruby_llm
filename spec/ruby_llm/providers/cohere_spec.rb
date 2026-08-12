# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Cohere do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    instance_double(
      RubyLLM::Configuration,
      request_timeout: 300,
      max_retries: 3,
      retry_interval: 0.1,
      retry_max_interval: 30,
      retry_interval_randomness: 0.5,
      retry_backoff_factor: 2,
      http_proxy: nil,
      faraday_adapter: :net_http,
      cohere_api_key: 'test-key',
      cohere_api_base: cohere_api_base
    )
  end
  let(:cohere_api_base) { nil }

  describe '#api_base' do
    it 'returns the default Cohere API URL' do
      expect(provider.api_base).to eq('https://api.cohere.com')
    end

    context 'when cohere_api_base is set' do
      let(:cohere_api_base) { 'https://custom-cohere-endpoint.example.com' }

      it 'returns the custom API URL' do
        expect(provider.api_base).to eq('https://custom-cohere-endpoint.example.com')
      end
    end
  end

  describe '#headers' do
    it 'authenticates with a bearer token' do
      expect(provider.headers).to eq('Authorization' => 'Bearer test-key')
    end
  end

  describe 'registration' do
    it 'is registered under the cohere slug' do
      expect(RubyLLM::Provider.resolve(:cohere)).to eq(described_class)
    end

    it 'speaks the Cohere protocol' do
      expect(described_class.protocols).to eq(cohere: RubyLLM::Protocols::Cohere)
    end

    it 'requires an API key' do
      expect(described_class.configuration_requirements).to eq(%i[cohere_api_key])
      expect(described_class.configuration_options).to eq(%i[cohere_api_key cohere_api_base])
    end
  end

  describe 'error parsing' do
    it 'reads the message Cohere returns on errors' do
      response = instance_double(Faraday::Response, body: { 'message' => 'no api key supplied' })

      expect(provider.parse_error(response)).to eq('no api key supplied')
    end
  end
end
