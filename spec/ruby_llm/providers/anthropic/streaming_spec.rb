# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::Streaming do
  include_context 'with configured RubyLLM'

  let(:test_obj) do
    Object.new.tap do |obj|
      obj.extend(RubyLLM::Providers::Anthropic::Tools)
      obj.extend(described_class)
    end
  end

  it 'normalizes finish_reason on streaming chunks' do
    data = {
      'type' => 'message_delta',
      'delta' => {
        'type' => 'text_delta',
        'text' => 'hello',
        'stop_reason' => 'max_tokens'
      }
    }

    allow(test_obj).to receive_messages(
      extract_model_id: 'claude-sonnet-4-5',
      extract_input_tokens: nil,
      extract_output_tokens: nil,
      extract_cached_tokens: nil,
      extract_cache_creation_tokens: nil,
      extract_tool_calls: nil
    )

    chunk = test_obj.send(:build_chunk, data)

    expect(chunk.content).to eq('hello')
    expect(chunk.finish_reason).to eq('length')
  end
end
