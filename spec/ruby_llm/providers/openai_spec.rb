# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI do
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
      openai_api_key: 'test-key',
      openai_api_base: nil,
      openai_organization_id: nil,
      openai_project_id: nil
    )
  end

  describe '#retry_delay' do
    def response_with(headers)
      Faraday::Env.from(response_headers: Faraday::Utils::Headers.new(headers))
    end

    it 'parses duration-formatted reset headers' do
      response = response_with('x-ratelimit-reset-requests' => '6m0s')

      expect(provider.retry_delay(response)).to eq(360.0)
    end

    it 'parses fractional seconds' do
      response = response_with('x-ratelimit-reset-requests' => '7.66s')

      expect(provider.retry_delay(response)).to eq(7.66)
    end

    it 'parses milliseconds' do
      response = response_with('x-ratelimit-reset-tokens' => '76ms')

      expect(provider.retry_delay(response)).to eq(0.076)
    end

    it 'parses hours' do
      response = response_with('x-ratelimit-reset-tokens' => '1h2m3s')

      expect(provider.retry_delay(response)).to eq(3723.0)
    end

    it 'returns the longer wait when both limits are hit' do
      response = response_with(
        'x-ratelimit-reset-requests' => '1s',
        'x-ratelimit-reset-tokens' => '2m30s'
      )

      expect(provider.retry_delay(response)).to eq(150.0)
    end

    it 'returns nil without rate limit headers' do
      expect(provider.retry_delay(response_with({}))).to be_nil
    end

    it 'returns nil for unparseable values' do
      response = response_with('x-ratelimit-reset-requests' => 'soon')

      expect(provider.retry_delay(response)).to be_nil
    end

    it 'returns nil when a duration contains trailing text' do
      response = response_with('x-ratelimit-reset-requests' => '1s later')

      expect(provider.retry_delay(response)).to be_nil
    end

    it 'returns nil when the response has no headers' do
      expect(provider.retry_delay(Faraday::Env.new)).to be_nil
    end
  end
end
