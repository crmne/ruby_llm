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

    it 'keeps the results of the latest round while they fit' do
      add_round(0, 9_000)
      add_round(1, 9_000)
      sent = sent_messages

      chat.complete

      expect(sent.first.select(&:tool_result?).map(&:content).first).to include('left out')
      expect(sent.first.reverse.find(&:tool_result?).content).to eq('x' * 9_000)
    end

    context 'when one round alone is over the budget' do
      def add_wide_round(*sizes)
        calls = sizes.each_index.to_h do |index|
          ["wide_#{index}", RubyLLM::ToolCall.new(id: "wide_#{index}", name: 'fetch', arguments: {})]
        end
        chat.add_message(role: :user, content: 'Fetch them all')
        chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls: calls))
        sizes.each_with_index do |size, index|
          chat.add_message(role: :tool, content: 'x' * size, tool_call_id: "wide_#{index}")
        end
      end

      def rejecting_overflow
        sent = []
        allow(chat.provider).to receive(:complete) do |messages, **|
          sent << messages
          size = messages.sum { |message| message.content.to_s.length }
          raise RubyLLM::ContextLengthExceededError, 'prompt is too long' if size > window * 2

          answer
        end
        sent
      end

      it 'does not leave the chat stuck on every later request' do
        add_wide_round(9_000, 9_000, 9_000)
        rejecting_overflow

        expect(chat.complete.content).to eq('done')
        expect(chat.ask('And now?').content).to eq('done')
      end

      it 'leaves out the oldest of its results, and keeps those that fit' do
        add_wide_round(9_000, 9_000, 3_000)
        sent = rejecting_overflow

        chat.complete

        contents = sent.first.select(&:tool_result?).map(&:content)
        expect(contents.first).to include('left out').and include('narrower')
        expect(contents.last(2)).to eq(['x' * 9_000, 'x' * 3_000])
        expect(chat.messages.select(&:tool_result?).map { |message| message.content.length })
          .to eq([9_000, 9_000, 3_000])
      end

      it 'leaves out a single result that takes more than the budget, and tells the model' do
        add_wide_round(30_000)
        sent = rejecting_overflow

        chat.complete

        expect(sent.first.find(&:tool_result?).content).to include('left out').and include('narrower')
      end

      it 'leaves out older rounds first' do
        add_round(0, 9_000)
        add_wide_round(6_000, 6_000)
        sent = rejecting_overflow

        chat.complete

        contents = sent.first.select(&:tool_result?).map(&:content)
        expect(contents.first).to include('left out')
        expect(contents.last(2)).to eq(['x' * 6_000, 'x' * 6_000])
      end
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

  describe 'window:' do
    before { allow(chat.model).to receive(:context_window).and_return(nil) }

    it 'reads back with the shares, and resets with nil' do
      chat.with_context_budget(window: 10_000, per_request: 0.7)

      expect(chat.context_budget).to eq(window: 10_000, per_request: 0.7)
      expect(chat.with_context_budget(nil).context_budget).to be_nil
    end

    it 'gives the shares a window for a model the registry does not know' do
      chat.with_tools(tool_returning('fetch', 'y' * 100_000)).with_context_budget(window: 10_000, per_result: 0.25)
      allow(chat.provider).to receive(:complete).and_return(call_message('fetch'), answer)

      chat.ask('Fetch')

      expect(chat.messages.find(&:tool_result?).content.length).to be < 100_000
    end

    it 'leaves results out of a request by that window' do
      chat.with_context_budget(window: 10_000, per_request: 0.7)
      6.times { |index| add_round(index, 3_000) }
      sent = sent_messages

      chat.complete

      expect(sent.first.find(&:tool_result?).content).to include('left out')
    end

    it 'wins over the window the registry knows' do
      allow(chat.model).to receive(:context_window).and_return(1_000_000)
      chat.with_context_budget(window: 10_000, per_request: 0.7)
      6.times { |index| add_round(index, 3_000) }
      sent = sent_messages

      chat.complete

      expect(sent.first.find(&:tool_result?).content).to include('left out')
    end

    it 'rejects anything but a positive whole number' do
      [0, -1, 1.5, '128000'].each do |window|
        expect { chat.with_context_budget(window:, per_request: 0.7) }.to raise_error(ArgumentError, /window/)
      end
    end

    it 'needs a share to apply it to' do
      expect { chat.with_context_budget(window: 10_000) }.to raise_error(ArgumentError, /per_result/)
    end

    it 'is taken by the Agent macro' do
      agent = Class.new(RubyLLM::Agent) { context_budget window: 10_000, per_request: 0.7 }

      expect(agent.chat.context_budget).to eq(window: 10_000, per_request: 0.7)
    end
  end

  describe 'a budget without a known window' do
    before { allow(chat.model).to receive(:context_window).and_return(nil) }

    def warnings
      logged = []
      allow(RubyLLM.logger).to receive(:warn) { |message = nil, &block| logged << (message || block.call) }
      logged
    end

    it 'warns once, naming the model and the option' do
      logged = warnings
      chat.with_context_budget(per_request: 0.7)
      2.times { |index| add_round(index, 10) }
      sent_messages

      2.times { chat.complete }

      expect(logged.grep(/context budget/).size).to eq(1)
      expect(logged.grep(/context budget/).first).to include(chat.model.id).and include('window:')
    end

    it 'warns when a result is added, before any request' do
      logged = warnings
      chat.with_tools(tool_returning('fetch', 'y' * 100)).with_context_budget(per_result: 0.25)
      allow(chat.provider).to receive(:complete).and_return(call_message('fetch'), answer)

      chat.ask('Fetch')

      expect(logged.grep(/context budget/).size).to eq(1)
    end

    it 'says nothing when a window is given or known' do
      logged = warnings
      chat.with_context_budget(window: 10_000, per_request: 0.7)
      add_round(0, 10)
      sent_messages

      chat.complete

      expect(logged.grep(/context budget/)).to be_empty
    end

    it 'says nothing without a budget' do
      logged = warnings
      add_round(0, 10)
      sent_messages

      chat.complete

      expect(logged.grep(/context budget/)).to be_empty
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
