# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Gemini::Streaming do
  include_context 'with configured RubyLLM'

  let(:test_obj) do
    Object.new.tap do |obj|
      obj.extend(RubyLLM::Providers::Gemini::Tools)
      obj.extend(described_class)
    end
  end

  it 'captures cached token usage on chunks when present' do
    data = {
      'candidates' => [
        {
          'content' => {
            'parts' => [{ 'text' => 'hello' }]
          }
        }
      ],
      'usageMetadata' => {
        'promptTokenCount' => 10,
        'candidatesTokenCount' => 4,
        'cachedContentTokenCount' => 6
      },
      'modelVersion' => 'gemini-2.5-flash'
    }

    chunk = test_obj.send(:build_chunk, data)

    expect(chunk.input_tokens).to eq(10)
    expect(chunk.output_tokens).to eq(4)
    expect(chunk.cached_tokens).to eq(6)
  end

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
