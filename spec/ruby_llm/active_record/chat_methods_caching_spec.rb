# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  def cache_key(chat, protocol: nil)
    record = Chat.find(chat.id)
    record.protocol = protocol
    record.with_caching.ask_later('Hi').render[:prompt_cache_key]
  end

  %i[responses chat_completions].each do |protocol|
    context "with #{protocol}" do
      it 'sends a cache key that stays the same for the chat across loads' do
        chat = Chat.create!(model: model_for(:openai), provider: :openai)

        key = cache_key(chat, protocol:)

        expect(key).to match(/\Aruby_llm-\h{32}\z/)
        expect(cache_key(chat, protocol:)).to eq(key)
        expect(cache_key(Chat.create!(model: model_for(:openai), provider: :openai), protocol:)).not_to eq(key)
      end

      it 'sends the cache key set with with_caching instead of its own' do
        chat = Chat.create!(model: model_for(:openai), provider: :openai)
        chat.protocol = protocol

        payload = chat.with_caching(key: 'account-7', ttl: '24h').ask_later('Hi').render

        expect(payload[:prompt_cache_key]).to eq('account-7')
      end
    end
  end

  it 'sends its cache key on the wire' do
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return_json(
      body: { id: 'resp_1', object: 'response', status: 'completed', model: model_for(:openai),
              output: [{ type: 'message', role: 'assistant', content: [{ type: 'output_text', text: 'Hello' }] }],
              usage: { input_tokens: 1, output_tokens: 1 } }
    )
    chat = Chat.create!(model: model_for(:openai), provider: :openai)
    key = cache_key(chat)

    chat.with_caching.ask('Hi')

    expect(key).to be_a(String)
    expect(a_request(:post, 'https://api.openai.com/v1/responses')
      .with { |request| JSON.parse(request.body)['prompt_cache_key'] == key }).to have_been_made
  end

  it 'sends no cache key before the chat is saved' do
    chat = Chat.new(model: model_for(:openai), provider: :openai)

    expect(chat.with_caching.to_llm.ask_later('Hi').render).not_to have_key(:prompt_cache_key)
  end

  it 'sends no cache key while caching is off' do
    chat = Chat.create!(model: model_for(:openai), provider: :openai)

    expect(chat.ask_later('Hi').render).not_to have_key(:prompt_cache_key)
    expect(chat.with_caching(false).render).not_to have_key(:prompt_cache_key)
  end

  it 'leaves its cache key out on a fallback to a provider that takes none' do
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return_json(
      status: 503, body: { error: { message: 'The server is overloaded.', type: 'server_error' } }
    )
    stub_request(:post, 'https://api.anthropic.com/v1/messages').to_return_json(
      body: { id: 'msg_1', type: 'message', role: 'assistant', model: model_for(:anthropic),
              content: [{ type: 'text', text: 'Hello from Claude' }], stop_reason: 'end_turn',
              usage: { input_tokens: 5, output_tokens: 3 } }
    )
    claude = RubyLLM.models.find(model_for(:anthropic), provider: :anthropic)
    chat = Chat.create!(model: model_for(:openai), provider: :openai)

    chat.with_caching.with_fallbacks(claude, on: [RubyLLM::ServiceUnavailableError]).ask('Hi')

    expect(chat.messages.last.content).to eq('Hello from Claude')
    expect(a_request(:post, 'https://api.anthropic.com/v1/messages')
      .with { |request| !request.body.include?('ruby_llm-') }).to have_been_made
  end

  it 'sends no cache key to a provider that takes none' do
    chat = Chat.create!(model: model_for(:anthropic), provider: :anthropic)

    expect(chat.with_caching.ask_later('Hi').render).not_to have_key(:prompt_cache_key)
  end
end
