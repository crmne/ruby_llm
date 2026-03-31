# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Streaming do
  include_context 'with configured RubyLLM'

  it 'normalizes finish_reason on streaming chunks' do
    data = {
      'model' => 'gpt-4o',
      'choices' => [
        {
          'finish_reason' => 'length',
          'delta' => {
            'content' => 'hello'
          }
        }
      ]
    }

    allow(described_class).to receive(:parse_tool_calls).and_return(nil)

    chunk = described_class.build_chunk(data)

    expect(chunk.content).to eq('hello')
    expect(chunk.finish_reason).to eq('length')
  end
end
