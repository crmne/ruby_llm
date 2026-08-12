# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Mantle do
  include_context 'with configured RubyLLM'

  let(:provider) { RubyLLM::Providers::Bedrock.new(RubyLLM.config) }

  describe 'protocol routing' do
    it 'routes un-versioned anthropic ids to mantle' do
      %w[anthropic.claude-sonnet-5 anthropic.claude-opus-4-7 anthropic.claude-fable-5].each do |id|
        model = RubyLLM::Model.default(id, 'bedrock')
        expect(provider.protocol_for(model)).to eq(described_class)
      end
    end

    it 'keeps dated and versioned ids on Converse' do
      %w[
        anthropic.claude-sonnet-4-5-20250929-v1:0
        us.anthropic.claude-sonnet-5
        amazon.nova-2-lite-v1:0
      ].each do |id|
        model = RubyLLM::Model.default(id, 'bedrock')
        expect(provider.protocol_for(model)).to eq(RubyLLM::Protocols::Converse)
      end
    end
  end

  describe 'request shape' do
    it 'renders an Anthropic Messages payload against the mantle endpoint' do
      chat = RubyLLM.chat(model: 'anthropic.claude-fable-5', provider: :bedrock, assume_model_exists: true)
      chat.ask_later('Say OK.')
      payload = chat.render

      expect(payload[:model]).to eq('anthropic.claude-fable-5')
      expect(payload[:messages].first[:role]).to eq('user')
    end

    it 'signs for the bedrock-mantle service' do
      headers = provider.sign_headers(
        'POST', 'anthropic/v1/messages', '{}',
        base_url: provider.mantle_api_base, service: described_class::SIGNING_SERVICE
      )

      expect(headers['Authorization']).to include('/bedrock-mantle/aws4_request')
      expect(headers['host'] || URI.parse(provider.mantle_api_base).host).to include('bedrock-mantle.')
    end

    it 'derives the mantle base from the region with a config override' do
      expect(provider.mantle_api_base).to include("bedrock-mantle.#{RubyLLM.config.bedrock_region}")
    end
  end

  describe 'signed requests', :live do
    it 'reaches the mantle endpoint with bedrock-mantle credentials' do
      url = 'v1/models'
      headers = provider.sign_headers('GET', url, '', base_url: provider.mantle_api_base,
                                                      service: described_class::SIGNING_SERVICE)

      response = provider.mantle_connection.get(url) { |req| req.headers.merge!(headers) }

      expect(response.body['data']).to be_an(Array)
      expect(response.body['data'].map { |model| model['id'] }).to include(a_string_including('anthropic.claude'))
    end
  end

  describe 'chat', skip: 'Claude on the mantle endpoint requires an AWS Sales agreement for this account' do
    it 'chats with the newest Claude generation' do
      chat = RubyLLM.chat(model: 'anthropic.claude-sonnet-5', provider: :bedrock, assume_model_exists: true)
      response = chat.ask('Say OK and nothing else.')

      expect(response.content).to be_present
    end
  end
end
