# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Converse::Streaming do
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

  it 'preserves raw stopReason from messageStop events' do
    event = {
      'messageStop' => {
        'stopReason' => 'max_tokens'
      }
    }

    chunk = streaming.send(:build_chunk, event)

    expect(chunk.finish_reason).to eq('max_tokens')
  end

  it 'extracts thinking tokens from nested usage output token details' do
    event = {
      'metadata' => {
        'usage' => {
          'inputTokens' => 10,
          'outputTokens' => 5,
          'outputTokensDetails' => { 'reasoningTokens' => 7 }
        }
      }
    }

    chunk = streaming.send(:build_chunk, event)

    expect(chunk.thinking_tokens).to eq(7)
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

  describe 'multi-block thinking' do
    # Feeds events through build_chunk with a single shared thinking_state hash,
    # mirroring how stream_response threads it across the whole event stream.
    def accumulate(events)
      accumulator = RubyLLM::StreamAccumulator.new
      thinking_state = {}
      events.each { |e| accumulator.add(streaming.send(:build_chunk, e, thinking_state)) }
      accumulator.to_message(nil)
    end

    it 'captures a single normal thinking block, matching today\'s fallback text/signature output' do
      events = [
        { 'contentBlockStart' => { 'contentBlockIndex' => 0,
                                   'start' => { 'reasoningContent' => {} } } },
        { 'contentBlockDelta' => { 'contentBlockIndex' => 0,
                                   'delta' => { 'reasoningContent' => { 'text' => 'thinking text' } } } },
        { 'contentBlockDelta' => { 'contentBlockIndex' => 0,
                                   'delta' => { 'reasoningContent' => { 'signature' => 'thinking-signature' } } } },
        { 'contentBlockStop' => { 'contentBlockIndex' => 0 } }
      ]

      message = accumulate(events)

      expect(message.thinking.text).to eq('thinking text')
      expect(message.thinking.signature).to eq('thinking-signature')
      expect(message.thinking.blocks).to eq(
        [
          { 'reasoningContent' => { 'reasoningText' => { 'text' => 'thinking text',
                                                         'signature' => 'thinking-signature' } } }
        ]
      )
    end

    it 'preserves a redacted thinking block followed by a normal thinking block, in order' do
      events = [
        { 'contentBlockStart' => { 'contentBlockIndex' => 0,
                                   'start' => { 'reasoningContent' => { 'redactedContent' => 'opaque-blob-1' } } } },
        { 'contentBlockStop' => { 'contentBlockIndex' => 0 } },
        { 'contentBlockStart' => { 'contentBlockIndex' => 1,
                                   'start' => { 'reasoningContent' => {} } } },
        { 'contentBlockDelta' => { 'contentBlockIndex' => 1,
                                   'delta' => { 'reasoningContent' => { 'text' => 'step two' } } } },
        { 'contentBlockDelta' => { 'contentBlockIndex' => 1,
                                   'delta' => { 'reasoningContent' => { 'signature' => 'sig-2' } } } },
        { 'contentBlockStop' => { 'contentBlockIndex' => 1 } },
        { 'contentBlockStart' => { 'contentBlockIndex' => 2, 'start' => { 'text' => {} } } },
        { 'contentBlockDelta' => { 'contentBlockIndex' => 2, 'delta' => { 'text' => 'Done' } } },
        { 'contentBlockStop' => { 'contentBlockIndex' => 2 } }
      ]

      message = accumulate(events)

      expect(message.thinking.blocks).to eq(
        [
          { 'reasoningContent' => { 'redactedContent' => 'opaque-blob-1' } },
          { 'reasoningContent' => { 'reasoningText' => { 'text' => 'step two', 'signature' => 'sig-2' } } }
        ]
      )
      expect(message.content).to eq('Done')
    end

    it 'preserves multiple normal thinking blocks separated by a tool_use block' do
      events = [
        { 'contentBlockStart' => { 'contentBlockIndex' => 0,
                                   'start' => { 'reasoningContent' => {} } } },
        { 'contentBlockDelta' => { 'contentBlockIndex' => 0,
                                   'delta' => { 'reasoningContent' => { 'text' => 'first thought' } } } },
        { 'contentBlockDelta' => { 'contentBlockIndex' => 0,
                                   'delta' => { 'reasoningContent' => { 'signature' => 'sig-1' } } } },
        { 'contentBlockStop' => { 'contentBlockIndex' => 0 } },
        { 'contentBlockStart' => { 'contentBlockIndex' => 1,
                                   'start' => { 'toolUse' => { 'toolUseId' => 'call_1', 'name' => 'search' } } } },
        { 'contentBlockDelta' => { 'contentBlockIndex' => 1,
                                   'delta' => { 'toolUse' => { 'input' => '{}' } } } },
        { 'contentBlockStop' => { 'contentBlockIndex' => 1 } },
        { 'contentBlockStart' => { 'contentBlockIndex' => 2,
                                   'start' => { 'reasoningContent' => {} } } },
        { 'contentBlockDelta' => { 'contentBlockIndex' => 2,
                                   'delta' => { 'reasoningContent' => { 'text' => 'second thought' } } } },
        { 'contentBlockDelta' => { 'contentBlockIndex' => 2,
                                   'delta' => { 'reasoningContent' => { 'signature' => 'sig-2' } } } },
        { 'contentBlockStop' => { 'contentBlockIndex' => 2 } }
      ]

      message = accumulate(events)

      expect(message.thinking.blocks).to eq(
        [
          { 'reasoningContent' => { 'reasoningText' => { 'text' => 'first thought', 'signature' => 'sig-1' } } },
          { 'reasoningContent' => { 'reasoningText' => { 'text' => 'second thought', 'signature' => 'sig-2' } } }
        ]
      )
      expect(message.tool_calls['call_1'].name).to eq('search')
    end

    it 'drops a thinking block left open when the turn is truncated before contentBlockStop' do
      events = [
        { 'contentBlockStart' => { 'contentBlockIndex' => 0,
                                   'start' => { 'reasoningContent' => {} } } },
        { 'contentBlockDelta' => { 'contentBlockIndex' => 0,
                                   'delta' => { 'reasoningContent' => { 'text' => 'cut off mid-thought' } } } },
        { 'messageStop' => { 'stopReason' => 'max_tokens' } }
      ]

      message = accumulate(events)

      expect(message.thinking.blocks).to be_nil
      expect(message.finish_reason).to eq('max_tokens')
    end

    it 'round-trips a streamed multi-block thinking turn through format_thinking_blocks unmodified' do
      events = [
        { 'contentBlockStart' => { 'contentBlockIndex' => 0,
                                   'start' => { 'reasoningContent' => { 'redactedContent' => 'opaque-blob-1' } } } },
        { 'contentBlockStop' => { 'contentBlockIndex' => 0 } },
        { 'contentBlockStart' => { 'contentBlockIndex' => 1,
                                   'start' => { 'reasoningContent' => {} } } },
        { 'contentBlockDelta' => { 'contentBlockIndex' => 1,
                                   'delta' => { 'reasoningContent' => { 'text' => 'step two' } } } },
        { 'contentBlockDelta' => { 'contentBlockIndex' => 1,
                                   'delta' => { 'reasoningContent' => { 'signature' => 'sig-2' } } } },
        { 'contentBlockStop' => { 'contentBlockIndex' => 1 } }
      ]

      message = accumulate(events)
      message.instance_variable_set(:@content, 'Done')
      formatted = RubyLLM::Protocols::Converse::Chat.format_messages([message])
      thinking_blocks = formatted.first[:content].select { |b| b.key?(:reasoningContent) || b.key?('reasoningContent') }

      expect(thinking_blocks).to eq(message.thinking.blocks)
    end
  end
end
