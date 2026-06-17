# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  it 'finds models by alias name' do
    # Core test - can we find a model using just its alias?
    chat = RubyLLM.chat(model: 'claude-haiku-4-5')
    expect(chat.model.id).to eq('claude-haiku-4-5')
    expect(chat.model.provider).to eq('anthropic')
  end

  it 'still supports exact model IDs' do
    # Backward compatibility check
    chat = RubyLLM.chat(model: 'claude-haiku-4-5-20251001')
    expect(chat.model.id).to eq('claude-haiku-4-5-20251001')
    expect(chat.model.provider).to eq('anthropic')
  end

  it 'finds models by alias and provider' do
    chat = RubyLLM.chat(model: 'claude-3-5-haiku', provider: :bedrock)
    expect(chat.model.id).to eq('anthropic.claude-3-5-haiku-20241022-v1:0')
    expect(chat.model.provider).to eq('bedrock')
  end

  it 'handles different provider prefixes correctly' do
    # Test that we can match models regardless of their provider prefix
    chat = RubyLLM.chat(model: 'claude-sonnet-4', provider: :bedrock)
    expect(chat.model.id).to eq('us.anthropic.claude-sonnet-4-20250514-v1:0')
    expect(chat.model.provider).to eq('bedrock')
  end

  it 'finds claude models on vertexai by their actual name' do
    chat = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :vertexai)
    expect(chat.model.id).to eq('claude-haiku-4-5')
    expect(chat.model.provider).to eq('vertexai')
  end

  it 'finds MaaS models on vertexai by their publisher-prefixed name' do
    chat = RubyLLM.chat(model: 'meta/llama-3.3-70b-instruct-maas', provider: :vertexai)
    expect(chat.model.id).to eq('meta/llama-3.3-70b-instruct-maas')
    expect(chat.model.provider).to eq('vertexai')
  end

  it 'finds MaaS models on vertexai by a clean alias' do
    chat = RubyLLM.chat(model: 'llama-3.3-70b-instruct', provider: :vertexai)
    expect(chat.model.id).to eq('meta/llama-3.3-70b-instruct-maas')
    expect(chat.model.provider).to eq('vertexai')
  end

  it 'resolves xAI provider aliases' do
    chat = RubyLLM.chat(model: 'grok-4-1-fast-non-reasoning', provider: :xai)
    expect(chat.model.id).to eq('grok-4.3')
    expect(chat.model.provider).to eq('xai')
  end
end
