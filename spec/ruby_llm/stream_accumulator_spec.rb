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

    it 'keeps interleaved tool call fragments separate by stream key' do
      accumulator = described_class.new

      chunks = [
        { 1 => RubyLLM::ToolCall.new(id: 'call_1', name: 'market_data', arguments: {}) },
        { 2 => RubyLLM::ToolCall.new(id: 'call_2', name: 'search', arguments: {}) },
        { 1 => RubyLLM::ToolCall.new(id: nil, name: nil, arguments: '{"symbol":"MNQM26",') },
        { 2 => RubyLLM::ToolCall.new(id: nil, name: nil, arguments: '{"query":"market news",') },
        { 1 => RubyLLM::ToolCall.new(id: nil, name: nil, arguments: '"interval":"minute"}') },
        { 2 => RubyLLM::ToolCall.new(id: nil, name: nil, arguments: '"date":"2026-03-31"}') }
      ]

      chunks.each do |tool_calls|
        accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: nil, tool_calls: tool_calls))
      end

      message = accumulator.to_message(nil)

      expect(message.tool_calls['call_1'].arguments).to eq(
        'symbol' => 'MNQM26',
        'interval' => 'minute'
      )
      expect(message.tool_calls['call_2'].arguments).to eq(
        'query' => 'market news',
        'date' => '2026-03-31'
      )
    end

    it 'deduplicates citations repeated across chunks' do
      accumulator = described_class.new
      citation = RubyLLM::Citation.new(url: 'https://example.com', title: 'Example')

      accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: 'Hello', citations: [citation]))
      accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: ' world', citations: [citation]))

      message = accumulator.to_message(nil)
      expect(message.citations).to eq([citation])
    end

    it 'resolves citation text spans from the accumulated content' do
      accumulator = described_class.new
      citation = RubyLLM::Citation.new(url: 'https://example.com', start_index: 6, end_index: 11)

      accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: 'Hello cited world'))
      accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: nil, citations: [citation]))

      message = accumulator.to_message(nil)
      expect(message.citations.first.text).to eq('cited')
      expect(message.citations.first.url).to eq('https://example.com')
    end
  end
end
