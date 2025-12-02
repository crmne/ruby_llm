# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::TogetherAI do
  let(:config) do
    instance_double(
      RubyLLM::Configuration,
      togetherai_api_key: 'test-api-key',
      request_timeout: 30,
      max_retries: 3,
      retry_interval: 1,
      retry_backoff_factor: 2,
      retry_interval_randomness: 0.5,
      http_proxy: nil,
      log_stream_debug: false
    )
  end

  let(:provider) { described_class.new(config) }

  describe '#initialize' do
    context 'with valid configuration' do
      it 'initializes successfully' do
        expect { provider }.not_to raise_error
      end
    end

    context 'without required API key' do
      let(:config) do
        instance_double(
          RubyLLM::Configuration,
          togetherai_api_key: nil,
          request_timeout: 30,
          max_retries: 3,
          retry_interval: 1,
          retry_backoff_factor: 2,
          retry_interval_randomness: 0.5,
          http_proxy: nil,
          log_stream_debug: false
        )
      end

      it 'raises a configuration error' do
        expect { provider }.to raise_error(RubyLLM::ConfigurationError)
      end
    end
  end

  describe '#api_base' do
    it 'returns the correct API base URL' do
      expect(provider.api_base).to eq('https://api.together.xyz/v1')
    end
  end

  describe '#headers' do
    it 'returns proper authentication headers' do
      expected_headers = {
        'Authorization' => 'Bearer test-api-key',
        'Content-Type' => 'application/json'
      }

      expect(provider.headers).to eq(expected_headers)
    end

    context 'when API key is nil' do
      it 'excludes nil values from headers' do
        # Create a provider instance and test headers with nil API key
        provider_instance = described_class.allocate
        provider_instance.instance_variable_set(:@config,
                                                instance_double(RubyLLM::Configuration, togetherai_api_key: nil))

        headers = provider_instance.headers

        expect(headers).to eq({ 'Content-Type' => 'application/json' })
        expect(headers).not_to have_key('Authorization')
      end
    end
  end

  describe '.capabilities' do
    it 'returns the TogetherAI capabilities module' do
      expect(described_class.capabilities).to eq(RubyLLM::Providers::TogetherAI::Capabilities)
    end
  end

  describe '.configuration_requirements' do
    it 'requires togetherai_api_key' do
      expect(described_class.configuration_requirements).to eq([:togetherai_api_key])
    end
  end

  describe 'included modules' do
    it 'includes the Chat module' do
      expect(described_class.included_modules).to include(RubyLLM::Providers::TogetherAI::Chat)
    end

    it 'includes the Models module' do
      expect(described_class.included_modules).to include(RubyLLM::Providers::TogetherAI::Models)
    end
  end
end
