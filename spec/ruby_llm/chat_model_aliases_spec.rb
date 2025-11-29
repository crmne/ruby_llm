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
    chat = RubyLLM.chat(model: 'claude-3-7-sonnet', provider: :bedrock)
    expect(chat.model.id).to eq('us.anthropic.claude-3-7-sonnet-20250219-v1:0')
    expect(chat.model.provider).to eq('bedrock')
  end
end
