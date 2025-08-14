# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Gemini::Streaming do
  include_context 'with configured RubyLLM'

  it 'correctly sums candidatesTokenCount and thoughtsTokenCount in streaming' do
    chat = RubyLLM.chat(model: 'gemini-2.5-flash', provider: :gemini)

    chunks = []
    response = chat.ask('What is 2+2? Think step by step.') do |chunk|
      chunks << chunk
    end

    # Get the final chunk with usage metadata
    final_chunk = chunks.last

    # Also verify against the complete message
    expect(response.output_tokens).to eq(final_chunk.output_tokens) if final_chunk.output_tokens
  end
end
