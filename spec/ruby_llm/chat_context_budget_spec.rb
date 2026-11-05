# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:chat) { described_class.new(model: model_for(:anthropic)) }
  let(:window) { 10_000 }

  before { allow(chat.model).to receive(:context_window).and_return(window) }

  def tool_returning(name, content)
    Class.new(RubyLLM::Tool) do
      define_singleton_method(:tool_name) { name }
      define_method(:execute) { content }
    end
  end

  def call_message(name, id = 'call_1')
    RubyLLM::Message.new(role: :assistant, content: '',
                         tool_calls: { id => RubyLLM::ToolCall.new(id:, name:, arguments: {}) })
  end

  def answer
    RubyLLM::Message.new(role: :assistant, content: 'done', input_tokens: 1, output_tokens: 1)
  end

  def sent_messages
    sent = []
    allow(chat.provider).to receive(:complete) do |messages, **|
      sent << messages
      answer
    end
    sent
  end

  def add_round(index, size)
    id = "call_#{index}"
    chat.add_message(role: :user, content: "Round #{index}")
    chat.add_message(call_message('fetch', id))
    chat.add_message(role: :tool, content: 'x' * size, tool_call_id: id)
  end

  describe '#with_context_budget' do
    it 'reads back what was set, and resets with nil' do
      expect(chat.with_context_budget(per_result: 0.25, per_request: 0.7)).to be(chat)
      expect(chat.context_budget).to eq(per_result: 0.25, per_request: 0.7)

      chat.with_context_budget(nil)

      expect(chat.context_budget).to be_nil
    end

    it 'takes a Hash' do
      chat.with_context_budget({ per_request: 0.5 })

      expect(chat.context_budget).to eq(per_request: 0.5)
    end

    it 'rejects shares outside zero to one and unknown options' do
      expect { chat.with_context_budget(per_result: 1.5) }.to raise_error(ArgumentError, /per_result/)
      expect { chat.with_context_budget(per_request: 0) }.to raise_error(ArgumentError, /per_request/)
      expect { chat.with_context_budget(per_turn: 0.5) }.to raise_error(ArgumentError, /per_turn/)
      expect { chat.with_context_budget }.to raise_error(ArgumentError)
    end
  end

  describe 'per_result' do
    it 'cuts a tool result longer than its share when it is added, with a note for the model' do
      chat.with_tools(tool_returning('fetch', 'y' * 100_000)).with_context_budget(per_result: 0.25)
      allow(chat.provider).to receive(:complete).and_return(call_message('fetch'), answer)

      chat.ask('Fetch')

      result = chat.messages.find(&:tool_result?).content
      expect(result.length).to be < 100_000
      expect(result).to start_with('y' * 1_000)
      expect(result).to include('100000').and include('narrower')
    end

    it 'leaves a result within its share alone' do
      chat.with_tools(tool_returning('fetch', 'short')).with_context_budget(per_result: 0.25)
      allow(chat.provider).to receive(:complete).and_return(call_message('fetch'), answer)

      chat.ask('Fetch')

      expect(chat.messages.find(&:tool_result?).content).to eq('short')
    end

    it 'leaves the result a file store already spilled to a file' do
      chat.with_tools(tool_returning('fetch', 'y' * 100_000))
          .with_file_store(:memory)
          .with_context_budget(per_result: 0.25)
      allow(chat.provider).to receive(:complete).and_return(call_message('fetch'), answer)

      chat.ask('Fetch')

      result = chat.messages.find(&:tool_result?).content
      expect(result).to include('read_file')
      expect(result).not_to include('narrower')
    end

    it 'does nothing without a context window' do
      allow(chat.model).to receive(:context_window).and_return(nil)
      chat.with_tools(tool_returning('fetch', 'y' * 100_000)).with_context_budget(per_result: 0.25)
      allow(chat.provider).to receive(:complete).and_return(call_message('fetch'), answer)

      chat.ask('Fetch')

      expect(chat.messages.find(&:tool_result?).content.length).to eq(100_000)
    end
  end

  describe 'per_request' do
    before { chat.with_tools(tool_returning('fetch', 'unused')).with_context_budget(per_request: 0.7) }

    it 'leaves the oldest tool results out of the request, not out of the transcript' do
      6.times { |index| add_round(index, 3_000) }
      sent = sent_messages

      chat.complete

      results = sent.first.select(&:tool_result?)
      expect(results.first.content).to include('left out')
      expect(results.last.content).to eq('x' * 3_000)
      expect(chat.messages.select(&:tool_result?).map(&:content)).to all(eq('x' * 3_000))
    end

    it 'keeps every call answered, so the request stays well formed' do
      6.times { |index| add_round(index, 3_000) }
      sent = sent_messages

      chat.complete

      expect(sent.first.select(&:tool_result?).map(&:tool_call_id)).to eq((0..5).map { |index| "call_#{index}" })
    end

    it 'sends everything while the request fits' do
      add_round(0, 3_000)
      sent = sent_messages

      chat.complete

      expect(sent.first.find(&:tool_result?).content).to eq('x' * 3_000)
    end

    it 'keeps the results of the latest round, which the model has not seen yet' do
      add_round(0, 30_000)
      sent = sent_messages

      chat.complete

      expect(sent.first.find(&:tool_result?).content).to eq('x' * 30_000)
    end

    it 'moves the cut in steps, so the same prefix goes out for many rounds' do
      allow(chat.model).to receive(:context_window).and_return(128_000)
      60.times { |index| add_round(index, 3_000) }
      sent = sent_messages
      cuts = Array.new(12) do |index|
        add_round(60 + index, 3_000)
        chat.complete
        sent.last.count { |message| message.tool_result? && message.content.include?('left out') }
      end

      expect(cuts.uniq.size).to be_between(2, 3)
      expect(cuts).to eq(cuts.sort)
    end

    it 'sends the same request prefix for the same messages, between steps' do
      sent = sent_messages
      9.times { |index| add_round(index, 3_000) }
      chat.complete
      first = sent.last.map(&:content)
      chat.add_message(role: :user, content: 'And?')
      chat.complete
      second = sent.last.map(&:content)

      expect(second.first(first.size)).to eq(first)
    end
  end

  describe 'Message#with' do
    it 'returns a copy with changed fields, leaving the original alone' do
      message = RubyLLM::Message.new(role: :tool, content: 'long', tool_call_id: 'call_1')

      copy = message.with(content: 'short')

      expect(copy.content).to eq('short')
      expect(copy.tool_call_id).to eq('call_1')
      expect(message.content).to eq('long')
    end

    it 'parses the new content' do
      message = RubyLLM::Message.new(role: :assistant, content: '{"a":1}')
      message.parsed

      expect(message.with(content: '{"a":2}').parsed).to eq('a' => 2)
    end

    it 'drops what the provider would replay with the old text' do
      citation = { url: 'https://example.com', cited_text: 'secret' }
      message = RubyLLM::Message.new(role: :assistant, content: 'secret', raw_content: [{ 'text' => 'secret' }],
                                     thinking: 'mine', thinking_signature: 'sig', citations: [citation], raw: 'secret')

      copy = message.with(content: 'redacted')

      expect(copy.raw_content).to be_nil
      expect(copy.thinking).to be_nil
      expect(copy.citations).to be_empty
      expect(copy.raw).to be_nil
      expect(copy.to_h.to_s).not_to include('secret')
      expect(message.raw_content).to eq([{ 'text' => 'secret' }])
    end

    it 'drops the MCP result that holds the old text of a tool result' do
      mcp_result = RubyLLM::MCP::Result.new('content' => [{ 'type' => 'text', 'text' => 'secret' }])
      message = RubyLLM::Message.new(role: :tool, content: 'secret', tool_call_id: 'call_1', mcp_result:)

      copy = message.with(content: 'redacted')

      expect(copy.mcp_result).to be_nil
      expect(copy.to_h.to_s).not_to include('secret')
      expect(message.mcp_result).to eq(mcp_result)
    end

    it 'rejects fields it cannot change' do
      message = RubyLLM::Message.new(role: :user, content: 'Hi')

      expect { message.with(colour: 'red') }.to raise_error(ArgumentError, /colour/)
      expect { message.with(tool_calls: {}) }.to raise_error(ArgumentError, /tool_calls/)
    end
  end
end
