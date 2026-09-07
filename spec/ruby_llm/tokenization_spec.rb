# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Tokenization do
  it 'keeps token IDs immutable and preserves the provider response' do
    ids = [1, 2]
    raw = { 'token_strings' => ['Hello', ' Ruby'] }
    result = described_class.new(ids:, model: model_for(:cohere), raw:)
    ids << 3

    expect(result.ids).to eq([1, 2])
    expect(result.ids).to be_frozen
    expect(result.count).to eq(2)
    expect(result.raw).to equal(raw)
  end

  it 'uses the context configuration and does not record generation usage' do
    model = model_for(:xai, :server_tools)
    context = RubyLLM.context do |config|
      config.xai_api_key = 'isolated-key'
      config.default_model = model
    end
    body = { token_ids: [{ token_id: 42, string_token: 'Ruby' }] }
    request = stub_request(:post, 'https://api.x.ai/v1/tokenize-text')
              .with(headers: { 'Authorization' => 'Bearer isolated-key' }, body: { model:, text: 'Ruby' }.to_json)
              .to_return_json(body:)
    allow(RubyLLM::Accounting::Usage).to receive(:instrument)
    result = context.tokenize('Ruby', provider: :xai)

    expect(result).to be_a(described_class)
    expect(result.ids).to eq([42])
    expect(result.model).to eq(model)
    expect(RubyLLM::Accounting::Usage).not_to have_received(:instrument)
    expect(request).to have_been_requested.once
  end

  it 'rejects non-text input before resolving a model or making a request' do
    expect { RubyLLM.tokenize(['Ruby']) }.to raise_error(ArgumentError, 'text must be a String')
  end

  it 'rejects providers without a text tokenizer before a request' do
    context = RubyLLM.context { |config| config.openai_api_key = 'test' }

    expect { context.tokenize('Ruby', model: model_for(:openai), provider: :openai) }
      .to raise_error(RubyLLM::Error, /doesn't support text tokenization/)
  end

  %i[xai cohere].each do |provider|
    it "tokenizes text with #{provider} through the public API", :live do
      model = provider == :xai ? model_for(provider, :server_tools) : model_for(provider)
      result = RubyLLM.tokenize('Ruby makes AI useful.', model:, provider:)

      expect(result).to be_a(described_class)
      expect(result.model).to eq(model)
      expect(result.ids).not_to be_empty
      expect(result.ids).to all(be_a(Integer))
      expect(result.count).to eq(result.ids.length)
      expect(result.raw).to be_a(Hash)
    end
  end
end
