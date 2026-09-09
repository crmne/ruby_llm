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
end
