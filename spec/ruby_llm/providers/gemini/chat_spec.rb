# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Gemini::Chat do
  include_context 'with configured RubyLLM'

  it 'correctly sums candidatesTokenCount and thoughtsTokenCount' do
    chat = RubyLLM.chat(model: 'gemini-2.5-flash', provider: :gemini)
    response = chat.ask('What is 2+2? Think step by step.')

    # Get the raw response to verify the token counting
    raw_body = response.raw.body

    candidates_tokens = raw_body.dig('usageMetadata', 'candidatesTokenCount') || 0
    thoughts_tokens = raw_body.dig('usageMetadata', 'thoughtsTokenCount') || 0

    # Verify our implementation correctly sums both token types
    expect(response.output_tokens).to eq(candidates_tokens + thoughts_tokens)
  end
end
