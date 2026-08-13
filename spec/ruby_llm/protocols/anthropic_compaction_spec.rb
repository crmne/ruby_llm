# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic do
  include_context 'with configured RubyLLM'

  let(:protocol) { described_class.new(RubyLLM::Providers::Anthropic.new(RubyLLM.config)) }

  describe 'compaction blocks' do
    let(:body) do
      {
        'content' => [
          { 'type' => 'compaction', 'content' => 'Summary of the conversation: earlier turns summarized.' },
          { 'type' => 'text', 'text' => 'The answer is 42.' }
        ],
        'stop_reason' => 'end_turn', 'model' => 'claude-sonnet-4-6', 'usage' => {}
      }
    end

    it 'surfaces compaction blocks and keeps raw content for replay' do
      message = protocol.send(:parse_completion_body, body, raw: nil)

      compaction = message.server_tool_calls.find { |call| call.type == 'compaction' }
      expect(compaction.result).to eq('Summary of the conversation: earlier turns summarized.')
      expect(message.content).to eq('The answer is 42.')
      expect(message.raw_content.first['type']).to eq('compaction')
    end

    it 'replays the compaction block verbatim in later turns' do
      message = protocol.send(:parse_completion_body, body, raw: nil)

      formatted = protocol.send(:format_message, message)

      expect(formatted[:content].first).to eq(body['content'].first)
    end

    it 'accumulates streamed compaction deltas into the reconstructed block' do
      protocol.send(:build_chunk, { 'type' => 'content_block_start', 'index' => 0,
                                    'content_block' => { 'type' => 'compaction' } })
      protocol.send(:build_chunk, { 'type' => 'content_block_delta', 'index' => 0,
                                    'delta' => { 'type' => 'compaction_delta', 'content' => 'Summary of ' } })
      protocol.send(:build_chunk, { 'type' => 'content_block_delta', 'index' => 0,
                                    'delta' => { 'type' => 'compaction_delta', 'content' => 'the conversation.' } })
      protocol.send(:build_chunk, { 'type' => 'content_block_stop', 'index' => 0 })
      chunk = protocol.send(:build_chunk, { 'type' => 'message_stop' })

      compaction = chunk.server_tool_calls.find { |call| call.type == 'compaction' }
      expect(compaction.result).to eq('Summary of the conversation.')
    end
  end

  describe 'usage on a compacted turn' do
    # Verified live: the top-level counts cover the final iteration only, so a
    # turn that compacted 99K tokens reports 187 there and the real bill in
    # usage.iterations.
    let(:usage) do
      {
        'input_tokens' => 187,
        'output_tokens' => 85,
        'cache_creation_input_tokens' => 0,
        'cache_read_input_tokens' => 0,
        'iterations' => [
          { 'input_tokens' => 99_207, 'output_tokens' => 125, 'cache_read_input_tokens' => 0,
            'cache_creation_input_tokens' => 0, 'type' => 'compaction' },
          { 'input_tokens' => 187, 'output_tokens' => 85, 'cache_read_input_tokens' => 0,
            'cache_creation_input_tokens' => 0, 'type' => 'message' }
        ]
      }
    end

    it 'bills every iteration, not just the final one' do
      message = protocol.send(:parse_completion_body,
                              { 'content' => [{ 'type' => 'text', 'text' => 'Hi.' }], 'usage' => usage },
                              raw: nil)

      expect(message.tokens.input).to eq(99_394)
      expect(message.tokens.output).to eq(210)
    end

    it 'sums cache tokens across iterations' do
      usage['iterations'][0]['cache_read_input_tokens'] = 1_000
      usage['iterations'][1]['cache_creation_input_tokens'] = 20

      message = protocol.send(:parse_completion_body,
                              { 'content' => [{ 'type' => 'text', 'text' => 'Hi.' }], 'usage' => usage },
                              raw: nil)

      expect(message.tokens.cache_read).to eq(1_000)
      expect(message.tokens.cache_write).to eq(20)
    end

    it 'reads the top-level counts when the response lists no iterations' do
      message = protocol.send(:parse_completion_body,
                              { 'content' => [{ 'type' => 'text', 'text' => 'Hi.' }],
                                'usage' => usage.except('iterations') },
                              raw: nil)

      expect(message.tokens.input).to eq(187)
      expect(message.tokens.output).to eq(85)
    end

    it 'sums iterations reported mid-stream' do
      chunk = protocol.send(:build_chunk, { 'type' => 'message_delta', 'usage' => usage })

      expect(chunk.tokens.output).to eq(210)
    end
  end
end
