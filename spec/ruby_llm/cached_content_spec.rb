# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::CachedContent, :live do
  # gemini-2.5-flash requires at least 2,048 tokens for a cacheable prefix.
  let(:long_text) do
    'The RubyLLM release engineering handbook describes cassette hygiene, provider wire ' \
    'format drift, backwards compatibility checks, and documentation accuracy reviews ' \
    'that every change must pass before release. ' * 300
  end

  describe 'explicit caching round-trip' do
    it "gemini/#{model_for(:gemini)} creates, uses, extends, and deletes a cache" do
      cache = RubyLLM.cache(
        long_text,
        model: model_for(:gemini),
        ttl: 300,
        instructions: 'You are a meticulous release engineer.'
      )

      expect(cache.name).to start_with('cachedContents/')
      expect(cache.model).to eq(model_for(:gemini))
      expect(cache.provider).to eq('gemini')
      expect(cache.tokens).to be > 2_048
      expect(cache.expires_at).to be_a(Time)

      response = RubyLLM.chat(model: model_for(:gemini), provider: :gemini)
                        .with_caching(id: cache)
                        .ask('In one short sentence, what does the cached handbook describe?')

      expect(response.content).to be_present
      expect(response.tokens.cache_read).to eq(cache.tokens)

      expires_at = cache.expires_at
      expect(cache.renew(ttl: 600)).to eq(cache)
      expect(cache.expires_at).to be > expires_at

      expect(cache.delete).to eq(cache)
    end

    it "vertexai/#{model_for(:vertexai)} creates, uses, and deletes a cache" do
      cache = RubyLLM.cache(long_text, model: model_for(:vertexai), provider: :vertexai, ttl: 300)

      expect(cache.name).to include('/cachedContents/')
      expect(cache.model).to eq(model_for(:vertexai))
      expect(cache.provider).to eq('vertexai')
      expect(cache.tokens).to be > 2_048

      response = RubyLLM.chat(model: model_for(:vertexai), provider: :vertexai)
                        .with_caching(id: cache)
                        .ask('In one short sentence, what does the cached handbook describe?')

      expect(response.content).to be_present
      expect(response.tokens.cache_read).to eq(cache.tokens)

      expect(cache.delete).to eq(cache)
    end

    it 'finds an existing cache by name' do
      created = RubyLLM.cache(long_text, model: model_for(:gemini), ttl: 300)

      found = described_class.find(created.name, provider: :gemini)

      expect(found.name).to eq(created.name)
      expect(found.tokens).to eq(created.tokens)

      created.delete
    end
  end

  describe 'unsupported providers' do
    it 'raises a clear error for providers without explicit caching' do
      expect do
        RubyLLM.cache('Some text', model: model_for(:anthropic))
      end.to raise_error(RubyLLM::Error, "Anthropic doesn't support explicit content caching")
    end
  end

  describe 'RubyLLM shortcuts' do
    it 'creates caches through RubyLLM.cache' do
      allow(described_class).to receive(:create).with('text', model: model_for(:gemini)).and_return(:cached)

      expect(RubyLLM.cache('text', model: model_for(:gemini))).to eq(:cached)
    end
  end
end
