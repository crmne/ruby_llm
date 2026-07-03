# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::Streaming do
  let(:protocol) { RubyLLM::Protocols::ChatCompletions.allocate }

  it 'preserves raw finish reasons on chunks' do
    chunk = protocol.send(
      :build_chunk,
      {
        'model' => 'gpt-4.1-nano',
        'choices' => [
          {
            'delta' => { 'content' => '' },
            'finish_reason' => 'tool_calls'
          }
        ]
      }
    )

    expect(chunk.finish_reason).to eq('tool_calls')
  end
end
