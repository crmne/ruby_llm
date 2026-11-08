# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:claude) { RubyLLM.models.find(model_for(:anthropic), provider: :anthropic) }
  let(:claude_reply) do
    { id: 'msg_1', type: 'message', role: 'assistant', model: claude.id,
      content: [{ type: 'text', text: 'Hello from Claude' }], stop_reason: 'end_turn',
      usage: { input_tokens: 5, output_tokens: 3 } }
  end
  let(:overloaded) { { error: { message: 'The server is overloaded.', type: 'server_error' } } }

  before do
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return_json(status: 503, body: overloaded)
    stub_request(:post, 'https://api.anthropic.com/v1/messages').to_return_json(body: claude_reply)
  end

  def anthropic_request
    request = nil
    expect(a_request(:post, 'https://api.anthropic.com/v1/messages').with { |req| request = JSON.parse(req.body) })
      .to have_been_made.once
    request
  end

  it 'falls back to a provider that has no use for the cache key, leaving the key out' do
    logged = []
    allow(RubyLLM.logger).to receive(:debug) { |message = nil, &block| logged << (block ? block.call : message) }
    chat = RubyLLM.chat(model: model_for(:openai), provider: :openai)
                  .with_caching(key: 'chat-1', ttl: '1h')
                  .with_fallbacks(claude, on: [RubyLLM::ServiceUnavailableError])

    expect(chat.ask('Hi').content).to eq('Hello from Claude')
    expect(anthropic_request['cache_control']).to eq('type' => 'ephemeral', 'ttl' => '1h')
    expect(logged).to include(a_string_matching(/left out :key from caching on a fallback to Anthropic/))
    expect(chat.caching).to eq(key: 'chat-1', ttl: '1h')
  end

  it 'keeps rejecting a caching option sent straight to a provider that cannot express it' do
    chat = RubyLLM.chat(model: claude.id, provider: :anthropic).with_caching(key: 'chat-1')

    expect { chat.ask('Hi') }.to raise_error(ArgumentError, /Anthropic prompt caching accepts :ttl, got :key/)
  end

  it 'leaves a cache key out on a fallback agent whose caching block sets one' do
    agent = Class.new(RubyLLM::Agent) do
      caching { { key: 'support' } }
    end
    agent.model model_for(:openai), provider: :openai
    agent.fallbacks claude, on: [RubyLLM::ServiceUnavailableError]

    expect(agent.chat.ask('Hi').content).to eq('Hello from Claude')
    expect(anthropic_request['cache_control']).to eq('type' => 'ephemeral')
  end

  describe 'what a fallback keeps' do
    def fallback_caching(provider, model, caching)
      provider_class = RubyLLM::Provider.resolve!(provider)
      provider_class.new(RubyLLM.config).fallback_caching(caching, model: RubyLLM.models.find(model, provider:))
    end

    it 'keeps an explicit cache id, which names content the prompt relies on' do
      expect(fallback_caching(:anthropic, model_for(:anthropic), id: 'cachedContents/1', key: 'k'))
        .to eq(id: 'cachedContents/1')
    end

    it 'keeps every option a provider that takes them can express, without a word' do
      allow(RubyLLM.logger).to receive(:debug)

      expect(fallback_caching(:openai, model_for(:openai), key: 'k', ttl: '24h', mode: 'implicit'))
        .to eq(key: 'k', ttl: '24h', mode: 'implicit')
      expect(RubyLLM.logger).not_to have_received(:debug)
    end

    it 'leaves out every option for a provider that caches on its own' do
      expect(fallback_caching(:cohere, model_for(:cohere), key: 'k', ttl: '1h')).to eq({})
    end

    it 'passes options through to a provider that ignores those it has no use for' do
      expect(fallback_caching(:gemini, model_for(:gemini), key: 'k')).to eq(key: 'k')
    end
  end

  describe 'which providers take a cache key' do
    {
      openai: true, mistral: true, meta: true, anthropic: false, cohere: false, gemini: false, openrouter: false
    }.each do |provider, takes_key|
      it "#{takes_key ? 'includes' : 'excludes'} #{provider}" do
        model = RubyLLM.models.find(model_for(provider), provider:)

        expect(RubyLLM::Provider.resolve!(provider).new(RubyLLM.config).cache_key?(model:)).to be(takes_key)
      end
    end
  end

  describe 'a chat whose run names a cache key' do
    def keyed_chat(model, provider)
      chat = RubyLLM.chat(model:, provider:)
      chat.run = Class.new(RubyLLM::Chat::Run) { def cache_key = 'ruby_llm-run' }.new
      chat.ask_later('Hi')
    end

    it 'sends it to a provider that takes one' do
      expect(keyed_chat(model_for(:openai), :openai).with_caching.render[:prompt_cache_key]).to eq('ruby_llm-run')
    end

    it 'sends none to a provider that takes none' do
      expect(keyed_chat(model_for(:anthropic), :anthropic).with_caching.render[:cache_control]).to eq(type: 'ephemeral')
    end

    it 'sends none unless caching is on' do
      chat = keyed_chat(model_for(:openai), :openai)

      expect(chat.render).not_to have_key(:prompt_cache_key)
      expect(chat.with_caching(false).render).not_to have_key(:prompt_cache_key)
    end
  end

  it 'sends no cache key of its own on a chat without a record' do
    payload = RubyLLM.chat(model: model_for(:openai), provider: :openai).with_caching.ask_later('Hi').render

    expect(payload).not_to have_key(:prompt_cache_key)
  end
end
