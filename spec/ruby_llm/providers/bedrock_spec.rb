# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock do
  subject(:provider) { described_class.new(RubyLLM.config) }

  include_context 'with configured RubyLLM'

  describe '#api_base' do
    it 'uses bedrock runtime endpoint for region' do
      allow(RubyLLM.config).to receive(:bedrock_region).and_return('eu-west-3')
      expect(provider.api_base).to eq('https://bedrock-runtime.eu-west-3.amazonaws.com')
    end
  end

  describe '#build_headers' do
    it 'sets content-type and accept based on streaming flag' do
      sig_headers = { 'authorization' => 'AWS4 ...' }

      h1 = provider.build_headers(sig_headers, streaming: false)
      expect(h1['Content-Type']).to eq('application/json')
      expect(h1['Accept']).to eq('application/json')

      h2 = provider.build_headers(sig_headers, streaming: true)
      expect(h2['Accept']).to eq('application/vnd.amazon.eventstream')
    end
  end

  describe '#parse_error' do
    it 'returns message from hash body' do
      response = instance_double(Faraday::Response, body: { 'message' => 'boom' })
      expect(provider.parse_error(response)).to eq('boom')
    end

    it 'joins messages from array body' do
      response = instance_double(Faraday::Response, body: [{ 'message' => 'one' }, { 'message' => 'two' }])
      expect(provider.parse_error(response)).to eq('one. two')
    end

    it 'returns body if not hash/array' do
      response = instance_double(Faraday::Response, body: 'raw error')
      expect(provider.parse_error(response)).to eq('raw error')
    end

    it 'returns nil for empty body' do
      response = instance_double(Faraday::Response, body: '')
      expect(provider.parse_error(response)).to be_nil
    end
  end

  describe '#build_request' do
    it 'builds request hash with payload and url' do
      url = 'https://example.com/test'
      payload = { a: 1 }
      req = provider.build_request(url, method: :post, payload:)
      expect(req[:http_method]).to eq(:post)
      expect(req[:url]).to eq(url)
      expect(req[:body]).to eq(JSON.generate(payload, ascii_only: false))
    end
  end

  describe '#create_signer' do
    it 'creates a signer with configured credentials' do
      signer = provider.create_signer
      expect(signer).to be_a(RubyLLM::Providers::Bedrock::Signing::Signer)
      expect(signer.service).to eq('bedrock')
      expect(signer.region).to eq(RubyLLM.config.bedrock_region)
    end
  end
end
