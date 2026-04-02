# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::StreamAccumulator do
  describe '#add' do
    it 'handles tool call deltas that omit arguments' do
      accumulator = described_class.new
      tool_call = RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: nil)
      chunk = RubyLLM::Chunk.new(role: :assistant, content: nil, tool_calls: { 'call_1' => tool_call })

      expect { accumulator.add(chunk) }.not_to raise_error

      message = accumulator.to_message(nil)
      expect(message.tool_calls['call_1'].arguments).to eq({})
    end

    context 'with parallel streaming tool calls' do
      it 'keeps arguments separate when block index is provided' do
        accumulator = described_class.new

        register_tool_call(accumulator, id: 'toolu_A', name: 'get_market_data', block_index: 1)
        register_tool_call(accumulator, id: 'toolu_B', name: 'web_search', block_index: 2)

        add_delta(accumulator, 'block_idx_1', '{"symbol":')
        add_delta(accumulator, 'block_idx_2', '{"query":')
        add_delta(accumulator, 'block_idx_1', '"MNQM26"}')
        add_delta(accumulator, 'block_idx_2', '"market news"}')

        message = accumulator.to_message(nil)

        expect(message.tool_calls['toolu_A'].arguments).to eq({ 'symbol' => 'MNQM26' })
        expect(message.tool_calls['toolu_B'].arguments).to eq({ 'query' => 'market news' })
      end
    end

    it 'falls back to latest_tool_call_id when no block index is provided' do
      accumulator = described_class.new

      tc = RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: +'')
      accumulator.add(
        RubyLLM::Chunk.new(role: :assistant, content: nil, tool_calls: { 'call_1' => tc })
      )

      delta = RubyLLM::ToolCall.new(id: nil, name: nil, arguments: '{"city":"NYC"}')
      accumulator.add(
        RubyLLM::Chunk.new(role: :assistant, content: nil, tool_calls: { nil => delta })
      )

      message = accumulator.to_message(nil)
      expect(message.tool_calls['call_1'].arguments).to eq({ 'city' => 'NYC' })
    end
  end

  private

  def register_tool_call(accumulator, id:, name:, block_index:)
    tc = RubyLLM::ToolCall.new(id: id, name: name, arguments: +'')
    register = RubyLLM::ToolCall.new(id: id, name: '_register_block_index', arguments: nil)
    accumulator.add(
      RubyLLM::Chunk.new(
        role: :assistant,
        content: nil,
        tool_calls: { id => tc, "register_idx_#{block_index}" => register }
      )
    )
  end

  def add_delta(accumulator, block_key, json_fragment)
    delta = RubyLLM::ToolCall.new(id: nil, name: nil, arguments: json_fragment)
    accumulator.add(
      RubyLLM::Chunk.new(role: :assistant, content: nil, tool_calls: { block_key => delta })
    )
  end
end
