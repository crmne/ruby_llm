# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  def render_with_identifier(model:, provider:, protocol: nil, identifier: 'user-123')
    RubyLLM.chat(model: model, provider: provider, protocol: protocol)
           .with_safety_identifier(identifier)
           .ask_later('Hello')
           .render
  end

  describe '#with_safety_identifier' do
    it 'returns self and remembers the identifier' do
      chat = RubyLLM.chat(model: 'gpt-4.1-nano', provider: :openai)

      expect(chat.with_safety_identifier('user-123')).to be(chat)
      expect(chat.safety_identifier).to eq('user-123')
    end

    it 'aliases with_user_id' do
      chat = RubyLLM.chat(model: 'gpt-4.1-nano', provider: :openai).with_user_id('user-123')

      expect(chat.safety_identifier).to eq('user-123')
    end

    it 'clears the identifier when given nil' do
      chat = RubyLLM.chat(model: 'gpt-4.1-nano', provider: :openai).with_safety_identifier('user-123')

      expect(chat.with_safety_identifier(nil).safety_identifier).to be_nil
    end

    it 'sends nothing when no identifier is set' do
      payload = RubyLLM.chat(model: 'gpt-4.1-nano', provider: :openai).ask_later('Hello').render

      expect(payload).not_to have_key(:safety_identifier)
    end
  end

  describe 'provider mapping' do
    it 'maps to safety_identifier on the OpenAI Responses API' do
      payload = render_with_identifier(model: 'gpt-4.1-nano', provider: :openai, protocol: :responses)

      expect(payload[:safety_identifier]).to eq('user-123')
    end

    it 'maps to safety_identifier on OpenAI Chat Completions' do
      payload = render_with_identifier(model: 'gpt-4.1-nano', provider: :openai, protocol: :chat_completions)

      expect(payload[:safety_identifier]).to eq('user-123')
    end

    it 'maps to metadata.user_id on Anthropic' do
      payload = render_with_identifier(model: 'claude-haiku-4-5', provider: :anthropic)

      expect(payload.dig(:metadata, :user_id)).to eq('user-123')
    end

    it 'maps to user_id on DeepSeek' do
      payload = render_with_identifier(model: 'deepseek-chat', provider: :deepseek)

      expect(payload[:user_id]).to eq('user-123')
    end

    it 'maps to user on OpenRouter' do
      payload = render_with_identifier(model: 'claude-haiku-4-5', provider: :openrouter)

      expect(payload[:user]).to eq('user-123')
    end

    it 'drops the identifier for providers without an equivalent field' do
      payload = render_with_identifier(model: 'gemini-2.5-flash', provider: :gemini)

      expect(payload.to_s).not_to include('user-123')
    end

    it 'lets provider options override the mapped value' do
      payload = RubyLLM.chat(model: 'gpt-4.1-nano', provider: :openai)
                       .with_safety_identifier('user-123')
                       .with_provider_options(safety_identifier: 'override')
                       .ask_later('Hello')
                       .render

      expect(payload[:safety_identifier]).to eq('override')
    end
  end
end
