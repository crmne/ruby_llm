# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Request headers' do # rubocop:disable RSpec/DescribeClass
  include_context 'with configured RubyLLM'

  let(:gateway) do
    RubyLLM.context do |config|
      config.openai_api_key = 'sk-test'
      config.request_headers = { 'X-Gateway-Key' => 'gw-secret' }
    end
  end
  let(:refusal) do
    { status: 400, body: { error: { message: 'refused' } }.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  def gateway_request(url, key = 'gw-secret')
    a_request(:post, url).with(headers: { 'X-Gateway-Key' => key })
  end

  def embed_through(context)
    stub_request(:post, 'https://api.openai.com/v1/embeddings')
      .to_return_json(body: { data: [{ index: 0, embedding: [0.1] }], usage: { prompt_tokens: 1 } })
    RubyLLM.embed('Ruby', model: model_for(:openai, :embedding), provider: :openai, context:)
  end

  it 'sends them with embeddings' do
    embed_through(gateway)

    expect(gateway_request('https://api.openai.com/v1/embeddings')).to have_been_made
  end

  it 'sends them with moderations' do
    stub_request(:post, 'https://api.openai.com/v1/moderations')
      .to_return_json(body: { id: 'modr-1', results: [{ flagged: false, categories: {}, category_scores: {} }] })

    gateway.moderate('Ruby')

    expect(gateway_request('https://api.openai.com/v1/moderations')).to have_been_made
  end

  it 'lets the provider authenticate over a header of the same name' do
    context = RubyLLM.context do |config|
      config.openai_api_key = 'sk-test'
      config.request_headers = { 'authorization' => 'Bearer gateway' }
    end

    embed_through(context)

    expect(a_request(:post, 'https://api.openai.com/v1/embeddings')
             .with(headers: { 'Authorization' => 'Bearer sk-test' })).to have_been_made
  end

  it 'lets a chat override them with with_headers' do
    stub_request(:post, %r{\Ahttps://api\.openai\.com/v1/}).to_return(refusal)
    chat = gateway.chat(model: model_for(:openai)).with_headers('X-Gateway-Key' => 'per-chat')

    expect { chat.ask('Hi') }.to raise_error(RubyLLM::BadRequestError)
    expect(gateway_request(%r{\Ahttps://api\.openai\.com/v1/}, 'per-chat')).to have_been_made
  end

  it 'sends each context its own on a shared connection' do
    other = RubyLLM.context do |config|
      config.openai_api_key = 'sk-test'
      config.request_headers = { 'X-Gateway-Key' => 'other' }
    end
    providers = [gateway, other].map { |context| RubyLLM::Providers::OpenAI.new(context.config) }
    stub_request(:get, 'https://api.openai.com/v1/models').to_return_json(body: { data: [] })

    providers.each { |provider| provider.connection.get('models') }

    expect(providers.map { |provider| provider.connection.connection }.uniq.size).to eq(1)
    expect(a_request(:get, 'https://api.openai.com/v1/models').with(headers: { 'X-Gateway-Key' => 'gw-secret' }))
      .to have_been_made.once
    expect(a_request(:get, 'https://api.openai.com/v1/models').with(headers: { 'X-Gateway-Key' => 'other' }))
      .to have_been_made.once
  end

  it 'keeps them off downloads' do
    stub_request(:get, 'https://files.example.test/notes.txt').to_return(body: 'notes')

    RubyLLM::Transport::Connection.download('https://files.example.test/notes.txt', gateway.config)

    expect(a_request(:get, 'https://files.example.test/notes.txt')
             .with { |request| !request.headers.key?('X-Gateway-Key') }).to have_been_made
  end
end
