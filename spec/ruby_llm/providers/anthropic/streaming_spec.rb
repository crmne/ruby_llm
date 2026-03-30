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

    allow(test_obj).to receive(:extract_model_id).and_return('claude-sonnet-4-5')
    allow(test_obj).to receive(:extract_input_tokens).and_return(nil)
    allow(test_obj).to receive(:extract_output_tokens).and_return(nil)
    allow(test_obj).to receive(:extract_cached_tokens).and_return(nil)
    allow(test_obj).to receive(:extract_cache_creation_tokens).and_return(nil)
    allow(test_obj).to receive(:extract_tool_calls).and_return(nil)

    chunk = test_obj.send(:build_chunk, data)

    expect(chunk.content).to eq('hello')
    expect(chunk.finish_reason).to eq('length')
  end
end