# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:log) { Queue.new }
  let(:chat) { described_class.new(model: model_for(:anthropic)) }

  def tool(name, alone: false)
    events = log
    Class.new(RubyLLM::Tool) do
      exclusive if alone
      define_singleton_method(:tool_name) { name }
      define_method(:execute) do
        events << [:start, name]
        sleep 0.05
        events << [:finish, name]
        name
      end
    end
  end

  def calls(*names)
    tool_calls = names.each_with_index.to_h do |name, index|
      ["call_#{index}", RubyLLM::ToolCall.new(id: "call_#{index}", name:, arguments: {})]
    end
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls:)
  end

  def answer
    RubyLLM::Message.new(role: :assistant, content: 'done', input_tokens: 1, output_tokens: 1)
  end

  def events
    Array.new(log.size) { log.pop }
  end

  def overlapping?(events, first, second)
    running = []
    events.each do |event, name|
      event == :start ? running << name : running.delete(name)
      return true if running.include?(first) && running.include?(second)
    end
    false
  end

  it 'declares a tool exclusive on its class and its instances' do
    expect(tool('click', alone: true)).to be_exclusive
    expect(tool('click', alone: true).new).to be_exclusive
    expect(tool('read')).not_to be_exclusive
  end

  it 'keeps the declaration in subclasses' do
    expect(Class.new(tool('click', alone: true))).to be_exclusive
  end

  %i[threads fibers].each do |mode|
    context "with #{mode}" do
      before do
        chat.with_tools(tool('read_a'), tool('read_b'), tool('click', alone: true), tool('type', alone: true))
            .with_tool_options(concurrency: mode)
      end

      it 'runs exclusive tools by themselves and the others in parallel' do
        allow(chat.provider).to receive(:complete).and_return(calls('read_a', 'read_b', 'click', 'type'), answer)

        chat.ask('Go')

        log = events
        expect(overlapping?(log, 'read_a', 'read_b')).to be(true)
        expect(overlapping?(log, 'click', 'type')).to be(false)
        %w[read_a read_b].each { |other| expect(overlapping?(log, 'click', other)).to be(false) }
        expect(log.index([:start, 'click'])).to be > log.index([:finish, 'read_b'])
      end

      it 'keeps the order the model gave around an exclusive call' do
        allow(chat.provider).to receive(:complete).and_return(calls('read_a', 'click', 'read_b'), answer)

        chat.ask('Go')

        log = events
        expect(log.index([:start, 'click'])).to be > log.index([:finish, 'read_a'])
        expect(log.index([:start, 'read_b'])).to be > log.index([:finish, 'click'])
        expect(chat.messages.select(&:tool_result?).map(&:content)).to eq(%w[read_a click read_b])
      end
    end
  end
end
