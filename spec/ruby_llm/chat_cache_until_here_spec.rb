# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, :live do
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

    it 'clears caching options with with_caching(nil)' do
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
                    .with_caching(key: 'repo:ruby_llm', ttl: '30m', mode: 'implicit')
                    .ask_later('Hello')

      payload = chat.render

      expect(payload[:prompt_cache_key]).to eq('repo:ruby_llm')
      expect(payload[:prompt_cache_options]).to eq(mode: 'implicit', ttl: '30m')
    end

    it 'translates deprecated retention: into prompt_cache_options' do
      allow(RubyLLM.logger).to receive(:warn)

      chat = RubyLLM.chat(model: 'gpt-4.1-nano')
                    .with_caching(key: 'repo:ruby_llm', retention: '24h')
                    .ask_later('Hello')

      payload = chat.render

      expect(payload[:prompt_cache_key]).to eq('repo:ruby_llm')
      expect(payload[:prompt_cache_options]).to eq(ttl: '24h')
      expect(RubyLLM.logger).to have_received(:warn).with(/retention: is deprecated/)
    end

    it 'rejects OpenAI caching options it cannot render' do
      chat = RubyLLM.chat(model: 'gpt-4.1-nano')
                    .with_caching(scope: 'user')
                    .ask_later('Hello')

      expect { chat.render }.to raise_error(ArgumentError, /Responses prompt caching accepts :key, :ttl, and :mode/)
    end

    it 'renders explicit breakpoints for OpenAI cache boundaries' do
      chat = RubyLLM.chat(model: 'gpt-4.1-nano')
      chat.ask_later('Long context').cache_until_here!

      payload = chat.render

      expect(payload[:input].last[:content]).to eq(
        [{ type: 'input_text', text: 'Long context', prompt_cache_breakpoint: { mode: 'explicit' } }]
      )
      expect(payload[:prompt_cache_options]).to eq(mode: 'explicit')
    end

    it 'sends cache-bounded instructions as input items on Responses' do
      chat = RubyLLM.chat(model: 'gpt-4.1-nano')
      chat.with_instructions('Stable instructions').cache_until_here!
      chat.ask_later('Hello')

      payload = chat.render

      expect(payload[:instructions]).to be_nil
      expect(payload[:input].first).to eq(
        role: 'system',
        content: [{ type: 'input_text', text: 'Stable instructions', prompt_cache_breakpoint: { mode: 'explicit' } }]
      )
    end
  end

  describe 'Gemini explicit caching' do
    it 'renders cachedContent when caching carries an id' do
      chat = RubyLLM.chat(model: 'gemini-2.5-flash', provider: :gemini)
                    .with_caching(id: 'cachedContents/abc123')
                    .ask_later('Hello')

      expect(chat.render[:cachedContent]).to eq('cachedContents/abc123')
    end

    it 'normalizes bare cache ids' do
      chat = RubyLLM.chat(model: 'gemini-2.5-flash', provider: :gemini)
                    .with_caching(id: 'abc123')
                    .ask_later('Hello')

      expect(chat.render[:cachedContent]).to eq('cachedContents/abc123')
    end

    it 'accepts a CachedContent as the id' do
      cache = RubyLLM::CachedContent.new(name: 'cachedContents/abc123')
      chat = RubyLLM.chat(model: 'gemini-2.5-flash', provider: :gemini)
                    .with_caching(id: cache)
                    .ask_later('Hello')

      expect(chat.render[:cachedContent]).to eq('cachedContents/abc123')
    end

    it 'notes that Gemini caching is implicit when with_caching has no id' do
      allow(RubyLLM.logger).to receive(:debug)

      chat = RubyLLM.chat(model: 'gemini-2.5-flash', provider: :gemini)
                    .with_caching(ttl: '1h')
                    .ask_later('Hello')
      payload = chat.render

      expect(payload).not_to have_key(:cachedContent)
      expect(RubyLLM.logger).to have_received(:debug).with(/implicit caching.*RubyLLM\.cache/m).once
    end

    it 'notes that Gemini ignores explicit cache boundaries' do
      allow(RubyLLM.logger).to receive(:debug)

      chat = RubyLLM.chat(model: 'gemini-2.5-flash', provider: :gemini)
      chat.ask_later('Long context').cache_until_here!
      chat.render

      expect(RubyLLM.logger).to have_received(:debug).with(/implicit caching.*RubyLLM\.cache/m).once
    end

    it 'rejects the id option on Anthropic' do
      chat = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic)
                    .with_caching(id: 'cachedContents/abc123')
                    .ask_later('Hello')

      expect { chat.render }.to raise_error(ArgumentError, /Anthropic prompt caching accepts :ttl, got :id/)
    end

    it 'rejects the id option on OpenAI' do
      chat = RubyLLM.chat(model: 'gpt-4.1-nano', provider: :openai)
                    .with_caching(id: 'cachedContents/abc123')
                    .ask_later('Hello')

      expect { chat.render }.to raise_error(ArgumentError, /prompt caching accepts :key, :ttl, and :mode, got :id/)
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

  describe 'prompt cache round-trip' do
    cacheable_models = [
      { provider: :anthropic, model: 'claude-haiku-4-5' },
      { provider: :bedrock, model: 'claude-haiku-4-5' }
    ]
    # Haiku models require at least 4096 tokens for a cacheable prefix.
    cacheable_instructions = <<~INSTRUCTIONS * 150
      You are a meticulous release engineer for the RubyLLM project. Review every
      change for backwards compatibility, provider wire-format drift, cassette
      hygiene, and documentation accuracy before approving it for release.
    INSTRUCTIONS

    each_model(cacheable_models) do |provider, model|
      it "#{provider}/#{model} writes then reads the prompt cache" do
        write_chat = RubyLLM.chat(model: model, provider: provider)
        write_chat.with_instructions(cacheable_instructions)
        write_chat.cache_until_here!
        first = write_chat.ask('Reply with exactly: OK')
        expect(first.tokens.cache_write.to_i + first.tokens.cache_read.to_i).to be_positive

        read_chat = RubyLLM.chat(model: model, provider: provider)
        read_chat.with_instructions(cacheable_instructions)
        read_chat.cache_until_here!
        second = read_chat.ask('Reply with exactly: OK')
        expect(second.tokens.cache_read).to be_positive
      end
    end

    it 'openai/gpt-5.2 reuses the prompt cache with a shared key' do
      ask_with_shared_key = lambda do
        chat = RubyLLM.chat(model: 'gpt-5.2', provider: :openai).with_caching(key: 'rubyllm-test')
        chat.with_instructions(cacheable_instructions)
        chat.ask('Reply with exactly: OK')
      end

      ask_with_shared_key.call
      second = ask_with_shared_key.call

      expect(second.tokens.cache_read.to_i + second.tokens.cache_write.to_i).to be_positive
    end
  end
end
