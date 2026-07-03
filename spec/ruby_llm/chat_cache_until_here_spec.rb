# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe '#with_caching' do
    it 'stores provider prompt cache options on the chat' do
      chat = RubyLLM.chat.with_caching(key: 'repo:ruby_llm', retention: '24h')

      expect(chat.caching).to eq(key: 'repo:ruby_llm', retention: '24h')
    end

    it 'enables provider-default prompt caching without options' do
      chat = RubyLLM.chat.with_caching

      expect(chat.caching).to eq({})
    end

    it 'replaces previous caching options' do
      chat = RubyLLM.chat.with_caching(key: 'repo:ruby_llm', retention: '24h')

      chat.with_caching(ttl: '1h')

      expect(chat.caching).to eq(ttl: '1h')
    end

    it 'keeps caching options when switching models on the same provider' do
      chat = RubyLLM.chat(model: 'gpt-4.1-nano').with_caching(retention: '24h')

      chat.with_model('gpt-5-nano')

      expect(chat.caching).to eq(retention: '24h')
    end

    it 'keeps caching options when switching providers' do
      chat = RubyLLM.chat(model: 'gpt-4.1-nano').with_caching(retention: '24h')

      chat.with_model('claude-haiku-4-5')

      expect(chat.caching).to eq(retention: '24h')
    end

    it 'lets the new provider reject incompatible caching options' do
      chat = RubyLLM.chat(model: 'gpt-4.1-nano')
                    .with_caching(retention: '24h')
                    .with_model('claude-haiku-4-5')
                    .ask_later('Hello')

      expect { chat.render }.to raise_error(ArgumentError, /Anthropic prompt caching accepts :ttl/)
    end

    it 'clears caching options explicitly' do
      chat = RubyLLM.chat.with_caching(ttl: '1h')

      expect(chat.with_caching(nil)).to eq(chat)
      expect(chat.caching).to be_nil
    end

    it 'rejects combining nil with caching options' do
      chat = RubyLLM.chat

      expect { chat.with_caching(nil, ttl: '1h') }.to raise_error(ArgumentError)
    end

    it 'renders OpenAI prompt cache controls as request params' do
      chat = RubyLLM.chat(model: 'gpt-4.1-nano')
                    .with_caching(key: 'repo:ruby_llm', retention: '24h')
                    .ask_later('Hello')

      payload = chat.render

      expect(payload[:prompt_cache_key]).to eq('repo:ruby_llm')
      expect(payload[:prompt_cache_retention]).to eq('24h')
    end

    it 'rejects OpenAI caching options it cannot render' do
      chat = RubyLLM.chat(model: 'gpt-4.1-nano')
                    .with_caching(ttl: '1h')
                    .ask_later('Hello')

      expect { chat.render }.to raise_error(ArgumentError, /Responses prompt caching accepts :key and :retention/)
    end
  end

  describe '#cache_until_here!' do
    let(:chat) { RubyLLM.chat }

    it 'marks the last added message as a cache boundary' do
      message = chat.add_message(role: :user, content: 'Long context')

      expect(chat.cache_until_here!).to eq(chat)
      expect(message.cache_until_here?).to be true
    end

    it 'marks the staged user message from ask_later' do
      chat.ask_later('Long context').cache_until_here!

      expect(chat.messages.last.cache_until_here?).to be true
    end

    it 'marks the instruction added by with_instructions' do
      chat.add_message(role: :user, content: 'Existing message')
      chat.with_instructions('Stable instructions').cache_until_here!

      system_message = chat.messages.find { |msg| msg.role == :system }
      user_message = chat.messages.find { |msg| msg.role == :user }
      expect(system_message.cache_until_here?).to be true
      expect(user_message.cache_until_here?).to be false
    end

    it 'raises when the chat has no messages' do
      expect { chat.cache_until_here! }.to raise_error(ArgumentError, 'No messages to cache')
    end
  end
end
