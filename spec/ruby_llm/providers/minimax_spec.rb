# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::MiniMax do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    RubyLLM::Configuration.new.tap do |provider_config|
      provider_config.minimax_api_key = 'test-key'
    end
  end
  let(:model_id) { model_for(:minimax) }
  let(:messages_url) { 'https://api.minimax.io/anthropic/v1/messages' }

  def context
    RubyLLM.context { |context_config| context_config.minimax_api_key = 'test-key' }
  end

  def stub_messages(body)
    stub_request(:post, messages_url)
      .with(headers: { 'Authorization' => 'Bearer test-key' })
      .to_return(status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def sent_body
    body = nil
    expect(a_request(:post, messages_url).with { |request| body = JSON.parse(request.body) }).to have_been_made
    body
  end

  def reply(content, usage: { input_tokens: 10, output_tokens: 5 })
    {
      id: 'msg_1', type: 'message', role: 'assistant', model: model_id,
      content: content, stop_reason: 'end_turn', usage: usage
    }
  end

  it "speaks MiniMax's dialect of the Anthropic Messages API" do
    expect(described_class.protocols).to eq(anthropic: described_class::Anthropic)
    expect(described_class::Anthropic.superclass).to eq(RubyLLM::Protocols::Anthropic)
  end

  it 'declares provider configuration' do
    expect(described_class.configuration_options).to eq(%i[minimax_api_key minimax_api_base])
    expect(described_class.configuration_requirements).to eq(%i[minimax_api_key])
  end

  it 'defaults to the international Anthropic-compatible endpoint and sends a bearer token' do
    expect(provider.api_base).to eq('https://api.minimax.io/anthropic')
    expect(provider.headers).to eq('Authorization' => 'Bearer test-key')
  end

  it 'talks to a configured endpoint instead of the default' do
    config.minimax_api_base = 'https://api.minimax.cn/anthropic'

    expect(provider.api_base).to eq('https://api.minimax.cn/anthropic')
  end

  it 'is a remote provider that requires an API key' do
    expect(described_class).not_to be_local
    expect(RubyLLM::Provider.remote_providers).to include(minimax: described_class)
    expect(described_class.configured?(RubyLLM::Configuration.new)).to be(false)
    expect(described_class.configured?(config)).to be(true)
  end

  it 'reads the models.dev minimax catalog' do
    expect(RubyLLM::Models::MODELS_DEV_PROVIDER_MAP).to include('minimax' => 'minimax')
    expect(RubyLLM.models.find(model_id, provider: :minimax).context_window).to eq(1_000_000)
  end

  it 'rejects provider tools, which the endpoint does not run' do
    chat = context.chat(model: model_id, provider: :minimax).with_provider_tools(:web_search)

    expect { chat.ask('Search the web') }.to raise_error(RubyLLM::UnsupportedServerToolError)
  end

  describe 'chat' do
    it 'parses thinking with its signature, and counts cached input' do
      stub_messages(reply(
                      [
                        { type: 'thinking', thinking: '17 times 23 is 391.', signature: 'abc123' },
                        { type: 'text', text: '391' }
                      ],
                      usage: { input_tokens: 18, output_tokens: 26, cache_creation_input_tokens: 0,
                               cache_read_input_tokens: 197, output_tokens_details: { thinking_tokens: 22 } }
                    ))

      response = context.chat(model: model_id, provider: :minimax).ask('What is 17*23?')

      expect(response.content).to eq('391')
      expect(response.thinking.text).to eq('17 times 23 is 391.')
      expect(response.thinking.signature).to eq('abc123')
      expect(response.tokens.input).to eq(18)
      expect(response.tokens.cache_read).to eq(197)
      expect(response.tokens.thinking).to eq(22)
    end

    it 'asks for adaptive thinking with an effort' do
      stub_messages(reply([{ type: 'text', text: 'Hi' }]))

      context.chat(model: model_id, provider: :minimax).with_thinking(effort: :low).ask('Hi')

      expect(sent_body).to include('thinking' => { 'type' => 'adaptive' }, 'output_config' => { 'effort' => 'low' })
    end

    it 'turns thinking off on models with a toggle' do
      stub_messages(reply([{ type: 'text', text: 'Hi' }]))

      context.chat(model: 'MiniMax-M3', provider: :minimax).with_thinking(false).ask('Hi')

      expect(sent_body['thinking']).to eq('type' => 'disabled')
    end
  end

  describe 'attachments' do
    let(:protocol) { described_class::Anthropic.new(provider, RubyLLM.models.find(model_id, provider: :minimax)) }

    it 'never uploads files to the provider' do
      expect(protocol.provider_file_references?).to be(false)
    end
  end
end
