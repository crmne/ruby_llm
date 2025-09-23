# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Mistral::Streaming do
  let(:test_obj) do
    Object.new.extend(described_class).tap do |obj|
      allow(obj).to receive(:parse_tool_calls).and_return([]) # ignore tool calls
    end
  end

  it 'correctly processes content on receiving reasoning messages (an array in choices.delta.content)' do
    data = {
      'choices' => [{
        'index' => 0,
        'delta' => {
          'content' => [{
            'type' => 'thinking',
            'thinking' => [{ 'type' => 'text', 'text' => 'Okay' }]
          }]
        }
      }]
    }
    expect(test_obj.send(:build_chunk, data).content).to eq('')
  end

  it 'correctly processes content on receiving normal messages' do
    data = {
      'choices' => [{
        'index' => 0,
        'delta' => { 'content' => 'thecontent' }
      }]
    }
    expect(test_obj.send(:build_chunk, data).content).to eq('thecontent')
  end
end
