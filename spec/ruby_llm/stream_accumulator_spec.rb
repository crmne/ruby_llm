# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::StreamAccumulator do
  describe '#add' do
    it 'ignores an empty model id from an initial chunk' do
      accumulator = described_class.new

      accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: '', model: ''))
      accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: 'Hi', model: 'gpt-5.4-2026-03-05'))

      message = accumulator.to_message(nil)
      expect(message.model).to eq('gpt-5.4-2026-03-05')
    end

    it 'keeps the first non-empty model id' do
      accumulator = described_class.new

      accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: 'Hi', model: 'model-a'))
      accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: '!', model: 'model-b'))

      message = accumulator.to_message(nil)
      expect(message.model).to eq('model-a')
    end

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

    it 'wraps malformed streamed tool call arguments in a RubyLLM error' do
      accumulator = described_class.new
      response = instance_double(Faraday::Response)

      accumulator.add(
        RubyLLM::Chunk.new(
          role: :assistant,
          content: nil,
          tool_calls: { 0 => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: '{"city":"Berlin"') }
        )
      )
      accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: nil, finish_reason: 'length'))

      error = nil

      expect do
        accumulator.to_message(response)
      rescue RubyLLM::ToolCallParseError => e
        error = e
        raise
      end.to raise_error(RubyLLM::ToolCallParseError)

      expect(error).to be_a(RubyLLM::Error)
      expect(error.response).to eq(response)
      expect(error.finish_reason).to eq('length')
      expect(error.cause).to be_a(JSON::ParserError)
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

    it 'preserves the final non-nil finish reason' do
      accumulator = described_class.new

      accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: 'Hello'))
      accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: nil, finish_reason: 'tool_use'))

      message = accumulator.to_message(nil)
      expect(message.finish_reason).to eq('tool_use')
    end
  end

  describe 'content accumulation' do
    def stream(*texts)
      accumulator = described_class.new
      texts.each { |text| accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: text)) }
      accumulator.to_message(nil)
    end

    it 'joins chunks in the order they arrived' do
      message = stream('just ', 'text')

      expect(message.content).to eq('just text')
      expect(message.thinking).to be_nil
    end

    it 'leaves markup in the content alone' do
      message = stream('<think>reasoning</think>answer')

      expect(message.content).to eq('<think>reasoning</think>answer')
      expect(message.thinking).to be_nil
    end
  end

  describe 'thinking deltas' do
    it 'keeps the first signature and joins the text' do
      accumulator = described_class.new
      accumulator.add(
        RubyLLM::Chunk.new(role: :assistant, content: nil, thinking: RubyLLM::Thinking.new(text: 'one '))
      )
      accumulator.add(
        RubyLLM::Chunk.new(role: :assistant, content: nil, thinking: RubyLLM::Thinking.new(signature: 'sig-1'))
      )
      accumulator.add(
        RubyLLM::Chunk.new(role: :assistant, content: nil, thinking: RubyLLM::Thinking.new(text: 'two',
                                                                                           signature: 'sig-2'))
      )

      message = accumulator.to_message(nil)

      expect(message.thinking.text).to eq('one two')
      expect(message.thinking.signature).to eq('sig-1')
    end
  end

  describe 'tool call fragments' do
    it 'gives an id-less tool call a generated id' do
      accumulator = described_class.new
      accumulator.add(
        RubyLLM::Chunk.new(
          role: :assistant, content: nil,
          tool_calls: { 0 => RubyLLM::ToolCall.new(id: '', name: 'weather', arguments: '') }
        )
      )

      expect(accumulator.tool_calls.values.first.id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'ignores a fragment for a tool call it never saw start' do
      accumulator = described_class.new
      accumulator.add(
        RubyLLM::Chunk.new(
          role: :assistant, content: nil,
          tool_calls: { 3 => RubyLLM::ToolCall.new(id: nil, name: nil, arguments: '{}') }
        )
      )

      expect(accumulator.tool_calls).to be_empty
    end

    it 'treats a nil argument fragment as empty' do
      accumulator = described_class.new
      accumulator.add(
        RubyLLM::Chunk.new(
          role: :assistant, content: nil,
          tool_calls: { 0 => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: +'{"a":') }
        )
      )
      accumulator.add(
        RubyLLM::Chunk.new(
          role: :assistant, content: nil,
          tool_calls: { 0 => RubyLLM::ToolCall.new(id: nil, name: nil, arguments: nil) }
        )
      )
      accumulator.add(
        RubyLLM::Chunk.new(
          role: :assistant, content: nil,
          tool_calls: { 0 => RubyLLM::ToolCall.new(id: nil, name: nil, arguments: '1}') }
        )
      )

      expect(accumulator.to_message(nil).tool_calls['call_1'].arguments).to eq('a' => 1)
    end

    it 'adopts a thought signature that arrives with a later fragment' do
      accumulator = described_class.new
      accumulator.add(
        RubyLLM::Chunk.new(
          role: :assistant, content: nil,
          tool_calls: { 0 => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: +'{}') }
        )
      )
      accumulator.add(
        RubyLLM::Chunk.new(
          role: :assistant, content: nil,
          tool_calls: { 0 => RubyLLM::ToolCall.new(id: nil, name: nil, arguments: '', thought_signature: 'sig') }
        )
      )

      expect(accumulator.to_message(nil).tool_calls['call_1'].thought_signature).to eq('sig')
    end

    it 'keeps hash arguments as they arrived' do
      accumulator = described_class.new
      accumulator.add(
        RubyLLM::Chunk.new(
          role: :assistant, content: nil,
          tool_calls: { 0 => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: { 'city' => 'Rome' }) }
        )
      )

      expect(accumulator.to_message(nil).tool_calls['call_1'].arguments).to eq('city' => 'Rome')
    end
  end

  describe 'debug logging' do
    it 'logs each chunk when stream debugging is on' do
      allow(RubyLLM.config).to receive(:log_stream_debug).and_return(true)
      allow(RubyLLM.logger).to receive(:debug)
      accumulator = described_class.new

      accumulator.add(
        RubyLLM::Chunk.new(
          role: :assistant, content: nil,
          tool_calls: { 0 => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: '{}') }
        )
      )

      expect(RubyLLM.logger).to have_received(:debug).at_least(:once)
    end
  end

  describe 'citation spans' do
    it 'leaves a citation alone when the span falls outside the content' do
      accumulator = described_class.new
      citation = RubyLLM::Citation.new(url: 'https://example.test', start_index: 100, end_index: 200)
      accumulator.add(RubyLLM::Chunk.new(role: :assistant, content: 'short', citations: [citation]))

      expect(accumulator.to_message(nil).citations.first.text).to be_nil
    end
  end
end
