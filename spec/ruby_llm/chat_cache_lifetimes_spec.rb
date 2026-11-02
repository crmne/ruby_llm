# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext/numeric/time'

RSpec.describe RubyLLM::Chat, :live do
  [3600, 1.hour, '1h'].each do |ttl|
    context "with a lifetime of #{ttl.inspect}" do
      it 'sends Anthropic the spelling its cache_control takes' do
        payload = RubyLLM.chat(model: model_for(:anthropic)).with_caching(ttl:).ask_later('Hello').render

        expect(payload[:cache_control]).to eq(type: 'ephemeral', ttl: '1h')
      end

      it 'sends OpenAI the spelling its prompt_cache_options take' do
        payload = RubyLLM.chat(model: model_for(:openai, :temperature)).with_caching(ttl:).ask_later('Hello').render

        expect(payload[:prompt_cache_options]).to eq(ttl: '1h')
      end

      it 'gives a cache boundary the same spelling' do
        chat = RubyLLM.chat(model: model_for(:anthropic)).with_caching
        chat.with_instructions('Stable policy').cache_until_here(ttl:)

        expect(chat.render[:system].last[:cache_control]).to eq(type: 'ephemeral', ttl: '1h')
      end

      it 'sends Bedrock Converse the spelling its cachePoint takes' do
        chat = RubyLLM.chat(model: model_for(:bedrock), provider: :bedrock).with_caching(ttl:)
        chat.with_instructions('Stable policy').cache_until_here

        expect(chat.render[:system].last).to eq(cachePoint: { type: 'default', ttl: '1h' })
      end

      it 'sends OpenRouter the spelling its cache_control takes' do
        chat = RubyLLM.chat(model: model_for(:openrouter), provider: :openrouter).with_caching(ttl:)
        chat.with_instructions('Stable policy').cache_until_here

        expect(chat.render[:messages].first[:content].last[:cache_control]).to eq(type: 'ephemeral', ttl: '1h')
      end

      it 'sends Gemini caches seconds' do
        protocol = Object.new.extend(RubyLLM::Protocols::Gemini::Caches)

        expect(protocol.send(:render_cache_update_payload, ttl:)).to eq(ttl: ttl == '1h' ? '1h' : '3600s')
      end
    end
  end
end
