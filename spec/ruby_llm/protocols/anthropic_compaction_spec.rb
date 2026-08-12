# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic do
  include_context 'with configured RubyLLM'

  let(:protocol) { described_class.new(RubyLLM::Providers::Anthropic.new(RubyLLM.config)) }

  describe 'compaction blocks' do
    let(:body) do
      {
        'content' => [
          { 'type' => 'compaction', 'summary' => [{ 'type' => 'text', 'text' => 'Earlier turns summarized.' }] },
          { 'type' => 'text', 'text' => 'The answer is 42.' }
        ],
        'stop_reason' => 'end_turn', 'model' => 'claude-sonnet-5', 'usage' => {}
      }
    end

    it 'surfaces compaction blocks and keeps raw content for replay' do
      message = protocol.send(:parse_completion_body, body, raw: nil)

      compaction = message.server_tool_calls.find { |call| call.type == 'compaction' }
      expect(compaction.result.first['text']).to eq('Earlier turns summarized.')
      expect(message.content).to eq('The answer is 42.')
      expect(message.raw_content.first['type']).to eq('compaction')
    end

    it 'replays the compaction block verbatim in later turns' do
      message = protocol.send(:parse_completion_body, body, raw: nil)

      formatted = protocol.send(:format_message, message)

      expect(formatted[:content].first['type']).to eq('compaction')
    end

    it 'accumulates streamed compaction deltas into the reconstructed block' do
      protocol.send(:build_chunk, { 'type' => 'content_block_start', 'index' => 0,
                                    'content_block' => { 'type' => 'compaction' } })
      protocol.send(:build_chunk, { 'type' => 'content_block_delta', 'index' => 0,
                                    'delta' => { 'type' => 'compaction_delta',
                                                 'summary' => [{ 'type' => 'text', 'text' => 'Summary part.' }] } })
      protocol.send(:build_chunk, { 'type' => 'content_block_stop', 'index' => 0 })
      chunk = protocol.send(:build_chunk, { 'type' => 'message_stop' })

      compaction = chunk.server_tool_calls.find { |call| call.type == 'compaction' }
      expect(compaction.result.first['text']).to eq('Summary part.')
    end
  end
end
