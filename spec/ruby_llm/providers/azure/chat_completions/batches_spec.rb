# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Azure::ChatCompletions::Batches do
  let(:config) do
    RubyLLM::Configuration.new.tap do |config|
      config.azure_api_base = 'https://example.openai.azure.com'
      config.azure_api_key = 'test'
    end
  end
  let(:provider) { RubyLLM::Providers::Azure.new(config) }
  let(:protocol) { RubyLLM::Providers::Azure.batch_protocols.fetch(:chat_completions).new(provider) }

  describe '#batch_endpoint' do
    it 'uses Azure endpoint paths without the OpenAI /v1 prefix' do
      expect(protocol.send(:batch_endpoint))
        .to eq('/chat/completions')
    end
  end

  describe '#batch_create_url' do
    it 'targets the resource openai/v1 batch endpoint' do
      expect(protocol.send(:batch_create_url))
        .to eq('https://example.openai.azure.com/openai/v1/batches')
    end
  end

  describe '#create_batch' do
    it 'rejects mixed-model batches' do
      requests = [
        { custom_id: '0', model: 'gpt-5-nano', params: { model: 'gpt-5-nano', messages: [] } },
        { custom_id: '1', model: 'gpt-5-mini', params: { model: 'gpt-5-mini', messages: [] } }
      ]

      expect { protocol.create_batch(requests) }.to raise_error(RubyLLM::Error, /one model/)
    end
  end
end
