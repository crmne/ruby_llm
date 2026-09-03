# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Message do
  let(:model) do
    RubyLLM::Model.new(
      id: 'priced-model',
      name: 'Priced Model',
      provider: 'openai',
      pricing: {
        text_tokens: {
          standard: {
            input_per_million: 1.0,
            output_per_million: 2.0
          }
        }
      }
    )
  end

  describe '#content' do
    it 'normalizes nil content to empty string for assistant tool-call messages' do
      tool_call = RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: {})
      message = described_class.new(role: :assistant, content: nil, tool_calls: { 'call_1' => tool_call })

      expect(message.content).to eq('')
    end

    it 'keeps nil content for messages without tool calls' do
      message = described_class.new(role: :assistant, content: nil, tool_calls: nil)

      expect(message.content).to be_nil
    end

    it 'rejects non-string content' do
      expect do
        described_class.new(role: :assistant, content: { name: 'Alice' })
      end.to raise_error(ArgumentError, /content must be a String/)
    end
  end

  describe '#parsed' do
    it 'parses JSON content' do
      message = described_class.new(role: :assistant, content: '{"name":"Alice","age":30}')

      expect(message.parsed).to eq({ 'name' => 'Alice', 'age' => 30 })
    end

    it 'returns nil for nil content' do
      message = described_class.new(role: :assistant, content: nil)

      expect(message.parsed).to be_nil
    end

    it 'raises for non-JSON content' do
      message = described_class.new(role: :assistant, content: 'plain text')

      expect { message.parsed }.to raise_error(JSON::ParserError)
    end

    it 'returns nil for a tool-call turn without text' do
      tool_call = RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: {})
      message = described_class.new(role: :assistant, content: nil, tool_calls: { 'call_1' => tool_call })

      expect(message.parsed).to be_nil
    end
  end

  describe '.new from #to_h attributes' do
    it 'rebuilds tool calls, thinking, and citations as value objects' do
      original = described_class.new(
        role: :assistant,
        content: 'Berlin is sunny.',
        tool_calls: {
          'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: { 'city' => 'Berlin' })
        },
        thinking: RubyLLM::Thinking.new(text: 'Check the forecast.', signature: 'sig'),
        citations: [RubyLLM::Citation.new(url: 'https://example.com', title: 'Forecast')],
        server_tool_calls: [RubyLLM::ServerToolCall.new(type: 'web_search', raw: { query: 'Berlin' })],
        finish_reason: 'stop'
      )

      rebuilt = described_class.new(original.to_h)

      expect(rebuilt.tool_calls['call_1']).to be_a(RubyLLM::ToolCall)
      expect(rebuilt.thinking).to be_a(RubyLLM::Thinking)
      expect(rebuilt.citations.first).to be_a(RubyLLM::Citation)
      expect(rebuilt.server_tool_calls.first).to be_a(RubyLLM::ServerToolCall)
      expect(rebuilt.to_h).to eq(original.to_h)
    end
  end

  describe '#attachments' do
    let(:image_path) { File.expand_path('../fixtures/ruby.png', __dir__) }

    it 'defaults to an empty array' do
      message = described_class.new(role: :user, content: 'hello')

      expect(message.attachments).to eq([])
    end

    it 'wraps a single source' do
      message = described_class.new(role: :user, content: 'look', attachments: image_path)

      expect(message.attachments.map(&:filename)).to eq(['ruby.png'])
    end

    it 'wraps grouped hash sources and skips blanks' do
      message = described_class.new(role: :user, content: 'look', attachments: { image: [image_path, nil, ''] })

      expect(message.attachments.map(&:filename)).to eq(['ruby.png'])
    end

    it 'appears in to_h only when present' do
      with_files = described_class.new(role: :user, content: 'look', attachments: image_path)
      without_files = described_class.new(role: :user, content: 'look')

      expect(with_files.to_h[:attachments].length).to eq(1)
      expect(without_files.to_h).not_to have_key(:attachments)
    end
  end

  describe '#cache_until_here' do
    it 'marks the message as a cache boundary' do
      message = described_class.new(role: :user, content: 'hello')

      expect(message.cache_until_here?).to be false
      expect(message.cache_until_here).to eq(message)
      expect(message.cache_until_here?).to be true
    end

    it 'can be initialized as a cache boundary' do
      message = described_class.new(role: :user, content: 'hello', cache_until_here: true)

      expect(message.cache_until_here?).to be true
    end
  end

  describe '#cost' do
    it 'calculates cost from the supplied model' do
      message = described_class.new(role: :assistant, content: 'Hello', input_tokens: 1_000, output_tokens: 2_000)

      expect(message.cost(model: model).total).to eq(0.005)
      expect(message.cost(model: model).to_h).to include(input: 0.001, output: 0.004, total: 0.005)
    end

    it 'uses the message model for cost lookup' do
      allow(RubyLLM.models).to receive(:find).and_call_original
      allow(RubyLLM.models).to receive(:find).with('priced-model').and_return(model)

      message = described_class.new(
        role: :assistant,
        content: 'Hello',
        input_tokens: 1_000,
        output_tokens: 2_000,
        model: 'priced-model'
      )

      expect(message.cost.total).to eq(0.005)
    end

    it 'returns nil when the message model cannot be found' do
      message = described_class.new(
        role: :assistant,
        content: 'Hello',
        input_tokens: 1_000,
        model: 'missing-model'
      )

      expect(message.cost.total).to be_nil
    end
  end

  describe '#tokens' do
    it 'always returns token and cost value objects' do
      message = described_class.new(role: :user, content: 'Hello')

      expect(message.tokens).to be_a(RubyLLM::Tokens)
      expect(message.tokens.to_h).to be_empty
      expect(message.cost).to be_a(RubyLLM::Cost)
      expect(message.cost.total).to be_nil
    end

    it 'exposes every bucket through the token value only' do
      message = described_class.new(
        role: :assistant,
        content: 'Hello',
        input_tokens: 10,
        output_tokens: 4,
        cache_read_tokens: 42,
        cache_write_tokens: 7,
        thinking_tokens: 2
      )

      expect(message.tokens.input).to eq(10)
      expect(message.tokens.output).to eq(4)
      expect(message.tokens.cache_read).to eq(42)
      expect(message.tokens.cache_write).to eq(7)
      expect(message.tokens.thinking).to eq(2)
      expect(message).not_to respond_to(
        :input_tokens, :output_tokens, :cache_read_tokens, :cache_write_tokens, :thinking_tokens, :usage
      )
    end
  end

  describe '#to_h' do
    it 'includes finish_reason when present' do
      message = described_class.new(role: :assistant, content: 'Hello', finish_reason: 'length')

      expect(message.finish_reason).to eq('length')
      expect(message.to_h[:finish_reason]).to eq('length')
    end

    it 'includes cache_until_here when marked' do
      message = described_class.new(role: :user, content: 'Hello').cache_until_here

      expect(message.to_h[:cache_until_here]).to be true
    end
  end

  describe 'finish reason predicates' do
    {
      stopped?: 'stop',
      max_tokens?: 'max_tokens',
      tool_call_stop?: 'tool_calls',
      content_filtered?: 'content_filter'
    }.each do |predicate, finish_reason|
      it "returns true for #{predicate} on the normalized #{finish_reason} reason" do
        message = described_class.new(role: :assistant, content: 'Hello', finish_reason: finish_reason)

        expect(message.public_send(predicate)).to be(true)
      end
    end

    it 'leaves provider spellings to the protocols' do
      message = described_class.new(role: :assistant, content: 'Hello', finish_reason: 'end_turn')

      expect(message).not_to be_stopped
      expect(message.finish_reason).to eq('end_turn')
    end

    it 'returns false when finish_reason is nil or unknown' do
      nil_message = described_class.new(role: :assistant, content: 'Hello', finish_reason: nil)
      unknown_message = described_class.new(role: :assistant, content: 'Hello', finish_reason: 'weird_provider_value')

      %i[stopped? max_tokens? tool_call_stop? content_filtered?].each do |predicate|
        expect(nil_message.public_send(predicate)).to be(false)
        expect(unknown_message.public_send(predicate)).to be(false)
      end
    end

    it 'is inherited by streaming chunks' do
      chunk = RubyLLM::Chunk.new(role: :assistant, content: nil, finish_reason: 'max_tokens')

      expect(chunk.max_tokens?).to be(true)
    end

    it 'reports a tool-call stop even when the provider says the turn completed' do
      tool_call = RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: {})
      message = described_class.new(role: :assistant, content: nil, tool_calls: { 'call_1' => tool_call },
                                    finish_reason: 'stop')

      expect(message).to be_tool_call_stop
      expect(message).not_to be_stopped
    end
  end

  describe '#tool_results' do
    let(:call) do
      described_class.new(
        role: :assistant,
        content: '',
        tool_calls: {
          'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: {}),
          'call_2' => RubyLLM::ToolCall.new(id: 'call_2', name: 'time', arguments: {})
        }
      )
    end
    let(:weather_result) { described_class.new(role: :tool, content: 'sunny', tool_call_id: 'call_1') }
    let(:time_result) { described_class.new(role: :tool, content: 'noon', tool_call_id: 'call_2') }

    before do
      conversation = instance_double(RubyLLM::Chat, messages: [call, weather_result, time_result])
      [call, weather_result, time_result].each { |message| message.conversation = conversation }
    end

    it 'returns the tool result messages answering the calls' do
      expect(call.tool_results).to eq([weather_result, time_result])
    end

    it 'returns an empty array for messages that made no tool calls' do
      expect(weather_result.tool_results).to eq([])
    end
  end
end
