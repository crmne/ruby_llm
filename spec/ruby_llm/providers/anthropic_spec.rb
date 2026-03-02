# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic do
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
      anthropic_api_key: 'test-key',
      anthropic_api_base: anthropic_api_base
    )
  end

  describe '#api_base' do
    context 'when anthropic_api_base is not set' do
      let(:anthropic_api_base) { nil }

      it 'returns the default Anthropic API URL' do
        expect(provider.api_base).to eq('https://api.anthropic.com')
      end
    end

    context 'when anthropic_api_base is set' do
      let(:anthropic_api_base) { 'https://custom-anthropic-endpoint.example.com' }

      it 'returns the custom API URL' do
        expect(provider.api_base).to eq('https://custom-anthropic-endpoint.example.com')
      end
    end
  end
end
