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
      anthropic_api_key: 'test-key'
    )
  end

  describe '#headers' do
    it 'includes User-Agent header' do
      headers = provider.headers
      expect(headers['User-Agent']).to match(/^ruby_llm\//)
    end

    it 'sets User-Agent to ruby_llm/<version>' do
      headers = provider.headers
      expect(headers['User-Agent']).to eq("ruby_llm/#{RubyLLM::VERSION}")
    end

    it 'includes x-api-key header' do
      headers = provider.headers
      expect(headers['x-api-key']).to eq('test-key')
    end

    it 'includes anthropic-version header' do
      headers = provider.headers
      expect(headers['anthropic-version']).to eq('2023-06-01')
    end
  end
end
