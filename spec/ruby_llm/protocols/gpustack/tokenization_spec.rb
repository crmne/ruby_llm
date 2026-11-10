# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::GPUStack::Tokenization do
  let(:model) { model_for(:gpustack) }
  let(:context) do
    RubyLLM.context do |config|
      config.gpustack_api_base = 'https://gpu.example.test/cluster/model/proxy/42/v1/'
      config.gpustack_api_key = 'isolated-key'
    end
  end

  it 'uses the model proxy tokenizer and preserves IDs and raw backend metadata without charging usage' do
    body = { tokens: [151_643, 123, 456], count: 3, max_model_len: 40_960 }
    request = stub_request(:post, 'https://gpu.example.test/cluster/model/proxy/42/tokenize')
              .with(headers: { 'Authorization' => 'Bearer isolated-key' }, body: { model:, prompt: 'Hello Ruby' })
              .to_return_json(body:)
    allow(RubyLLM::Accounting::Usage).to receive(:instrument)

    result = context.tokenize('Hello Ruby', model:, provider: :gpustack)

    expect(result).to have_attributes(ids: [151_643, 123, 456], count: 3, model:)
    expect(result.raw['max_model_len']).to eq(40_960)
    expect(RubyLLM::Accounting::Usage).not_to have_received(:instrument)
    expect(request).to have_been_requested.once
  end

  it 'rejects gateway tokenization before issuing a request' do
    context.config.gpustack_api_base = 'https://gpu.example.test/cluster/v1'

    expect { context.tokenize('Ruby', model:, provider: :gpustack) }
      .to raise_error(RubyLLM::Error, %r{/model/proxy/ROUTE_ID/v1})
    expect(a_request(:post, /gpu.example.test/)).not_to have_been_made
  end

  it 'keeps tokenization on its dialect when Responses is the configured chat protocol' do
    context.config.gpustack_protocol = :responses
    stub_request(:post, 'https://gpu.example.test/cluster/model/proxy/42/tokenize')
      .to_return_json(body: { tokens: [123], count: 1 })

    expect(context.tokenize('Ruby', model:, provider: :gpustack).ids).to eq([123])
  end

  describe 'Chat#count_tokens' do
    let(:chat) { context.chat(model:, provider: :gpustack) }

    it 'counts the conversation through the model proxy tokenizer' do
      request = stub_request(:post, 'https://gpu.example.test/cluster/model/proxy/42/tokenize')
                .with(headers: { 'Authorization' => 'Bearer isolated-key' },
                      body: { model:, messages: [{ role: 'system', content: 'Be terse.' },
                                                 { role: 'user', content: 'Hello Ruby' }] })
                .to_return_json(body: { tokens: [1, 2, 3, 4], count: 4, max_model_len: 2048 })

      count = chat.with_instructions('Be terse.').count_tokens('Hello Ruby')

      expect(count).to eq(4)
      expect(chat.messages.map(&:role)).to eq([:system])
      expect(request).to have_been_requested.once
    end

    it 'includes declared tools and leaves out generation-only fields' do
      tool = Class.new(RubyLLM::Tool) do
        def self.name = 'Weather'
        description 'Reports the weather'
      end
      request = stub_request(:post, 'https://gpu.example.test/cluster/model/proxy/42/tokenize').with do |req|
        body = JSON.parse(req.body)
        body.keys.sort == %w[messages model tools] && body['tools'].first.dig('function', 'name') == 'weather'
      end.to_return_json(body: { tokens: [1], count: 1 })

      expect(chat.with_tools(tool).with_schema({ type: 'object', properties: {} }).count_tokens('Hi')).to eq(1)
      expect(request).to have_been_requested.once
    end

    it 'rejects the gateway base before issuing a request' do
      context.config.gpustack_api_base = 'https://gpu.example.test/cluster/v1'

      expect { chat.count_tokens('Ruby') }.to raise_error(RubyLLM::Error, %r{/model/proxy/ROUTE_ID/v1})
      expect(a_request(:post, /gpu.example.test/)).not_to have_been_made
    end
  end
end
