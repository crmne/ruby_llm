# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Meta do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    RubyLLM::Configuration.new.tap do |provider_config|
      provider_config.meta_api_key = 'test-key'
    end
  end
  let(:model_id) { model_for(:meta) }
  let(:responses_url) { 'https://api.meta.ai/v1/responses' }

  def context
    RubyLLM.context { |context_config| context_config.meta_api_key = 'test-key' }
  end

  def stub_response(output: [{ type: 'message', role: 'assistant', content: [{ type: 'output_text', text: 'Hi' }] }],
                    usage: { input_tokens: 12, output_tokens: 3, total_tokens: 15 })
    stub_request(:post, responses_url)
      .with(headers: { 'Authorization' => 'Bearer test-key' })
      .to_return(status: 200, body: {
        id: 'resp_1', object: 'response', status: 'completed', model: model_id, output: output, usage: usage
      }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def sent_body
    body = nil
    expect(a_request(:post, responses_url).with { |request| body = JSON.parse(request.body) }).to have_been_made
    body
  end

  it "speaks Meta's dialect of the Responses API" do
    expect(described_class.protocols).to eq(responses: described_class::Responses)
    expect(described_class::Responses.superclass).to eq(RubyLLM::Protocols::Responses)
  end

  it 'declares provider configuration' do
    expect(described_class.configuration_options).to eq(%i[meta_api_key meta_api_base])
    expect(described_class.configuration_requirements).to eq(%i[meta_api_key])
  end

  it 'defaults to the Meta Model API and sends a bearer token' do
    expect(provider.api_base).to eq('https://api.meta.ai/v1')
    expect(provider.headers).to eq('Authorization' => 'Bearer test-key')
  end

  it 'talks to a configured endpoint instead of the default' do
    config.meta_api_base = 'https://meta-proxy.example.com/v1'

    expect(provider.api_base).to eq('https://meta-proxy.example.com/v1')
  end

  it 'is a remote provider that requires an API key' do
    expect(described_class).not_to be_local
    expect(RubyLLM::Provider.remote_providers).to include(meta: described_class)
    expect(described_class.configured?(RubyLLM::Configuration.new)).to be(false)
    expect(described_class.configured?(config)).to be(true)
  end

  it 'reads the models.dev meta catalog' do
    expect(RubyLLM::Models::MODELS_DEV_PROVIDER_MAP).to include('meta' => 'meta')
    expect(RubyLLM.models.find(model_id, provider: :meta).context_window).to eq(1_048_576)
  end

  describe 'chat' do
    it 'runs stateless, replays encrypted reasoning, and names the end user' do
      stub_response

      context.chat(model: model_id, provider: :meta).with_end_user('user-42').ask('Hello')

      expect(sent_body).to include(
        'store' => false,
        'include' => ['reasoning.encrypted_content'],
        'safety_identifier' => 'user-42'
      )
    end

    it 'keeps the encrypted reasoning, and counts cached input and reasoning tokens' do
      stub_response(
        output: [
          { type: 'reasoning', id: 'rs_1', summary: [], encrypted_content: 'sealed' },
          { type: 'message', role: 'assistant', content: [{ type: 'output_text', text: '391' }] }
        ],
        usage: { input_tokens: 100, output_tokens: 30, total_tokens: 130,
                 input_tokens_details: { cached_tokens: 80 }, output_tokens_details: { reasoning_tokens: 20 } }
      )

      response = context.chat(model: model_id, provider: :meta).ask('What is 17*23?')

      expect(response.content).to eq('391')
      expect(response.thinking.signature).to eq('sealed')
      expect(response.tokens.input).to eq(20)
      expect(response.tokens.cache_read).to eq(80)
      expect(response.tokens.thinking).to eq(20)
    end

    it 'sets the reasoning effort' do
      stub_response

      context.chat(model: model_id, provider: :meta).with_thinking(effort: :max).ask('Hello')

      expect(sent_body['reasoning']).to eq('effort' => 'max')
    end

    it 'sends a cache key and retention without breakpoints' do
      stub_response

      context.chat(model: model_id, provider: :meta).with_caching(key: 'docs', ttl: '24h').ask('Hello')

      expect(sent_body).to include('prompt_cache_key' => 'docs', 'prompt_cache_retention' => '24h')
      expect(sent_body.to_json).not_to include('prompt_cache_breakpoint')
    end

    it 'rejects cache options Meta does not take' do
      chat = context.chat(model: model_id, provider: :meta).with_caching(mode: 'explicit')

      expect { chat.ask('Hello') }.to raise_error(ArgumentError, /accepts :key and :ttl/)
    end

    it 'grounds answers in web search, and refuses other provider tools' do
      stub_response

      context.chat(model: model_id, provider: :meta).with_provider_tools(:web_search).ask('News?')

      expect(sent_body['tools']).to eq([{ 'type' => 'web_search' }])
      expect do
        context.chat(model: model_id, provider: :meta).with_provider_tools(:code_execution).ask('Run it')
      end.to raise_error(RubyLLM::UnsupportedServerToolError)
    end
  end

  it 'counts input tokens with the Responses endpoint' do
    stub_request(:post, 'https://api.meta.ai/v1/responses/input_tokens')
      .to_return(status: 200, body: { object: 'response.input_tokens', input_tokens: 7 }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    expect(context.chat(model: model_id, provider: :meta).count_tokens('Hello')).to eq(7)
  end
end
