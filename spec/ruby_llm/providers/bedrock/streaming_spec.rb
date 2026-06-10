# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Streaming do
  let(:streaming) do
    Object.new.tap do |object|
      object.extend(described_class)
      object.instance_variable_set(:@model, instance_double(RubyLLM::Model::Info, id: 'bedrock-test-model'))
    end
  end

  it 'extracts thinking text from Bedrock Converse Stream reasoningContent deltas' do
    event = {
      'contentBlockDelta' => {
        'delta' => {
          'reasoningContent' => {
            'text' => 'thinking text'
          }
        }
      }
    }

    chunk = streaming.send(:build_chunk, event)

    expect(chunk.thinking.text).to eq('thinking text')
  end

  it 'extracts thinking signatures from Bedrock Converse Stream reasoningContent deltas' do
    event = {
      'contentBlockDelta' => {
        'delta' => {
          'reasoningContent' => {
            'signature' => 'thinking-signature'
          }
        }
      }
    }

    chunk = streaming.send(:build_chunk, event)

    expect(chunk.thinking.signature).to eq('thinking-signature')
  end

  it 'accumulates Bedrock Converse Stream thinking deltas into the final message' do
    accumulator = RubyLLM::StreamAccumulator.new
    text_event = {
      'contentBlockDelta' => {
        'delta' => {
          'reasoningContent' => {
            'text' => 'thinking text'
          }
        }
      }
    }
    signature_event = {
      'contentBlockDelta' => {
        'delta' => {
          'reasoningContent' => {
            'signature' => 'thinking-signature'
          }
        }
      }
    }

    accumulator.add(streaming.send(:build_chunk, text_event))
    accumulator.add(streaming.send(:build_chunk, signature_event))
    message = accumulator.to_message(nil)

    expect(message.thinking.text).to eq('thinking text')
    expect(message.thinking.signature).to eq('thinking-signature')
  end
end
