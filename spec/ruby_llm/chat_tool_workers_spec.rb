# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:chat) { described_class.new(model: model_for(:anthropic)).with_tools(lookup) }
  let(:running) { { now: 0, peak: 0, lock: Mutex.new } }

  let(:lookup) do
    running = self.running
    Class.new(RubyLLM::Tool) do
      define_singleton_method(:tool_name) { 'lookup' }
      define_method(:execute) do
        running[:lock].synchronize { running[:peak] = [running[:peak], running[:now] += 1].max }
        sleep 0.02
        running[:lock].synchronize { running[:now] -= 1 }
        'found'
      end
    end
  end

  def calls(count)
    tool_calls = Array.new(count) { |index| "call_#{index}" }.to_h do |id|
      [id, RubyLLM::ToolCall.new(id:, name: 'lookup', arguments: {})]
    end
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls:)
  end

  def answer
    RubyLLM::Message.new(role: :assistant, content: 'done', input_tokens: 1, output_tokens: 1)
  end

  describe 'with_tool_options(workers:)' do
    it 'is off by default' do
      expect(chat.tool_options[:workers]).to be_nil
    end

    it 'keeps the limit beside the other options and returns the chat' do
      expect(chat.with_tool_options(concurrency: :threads, workers: 4)).to be(chat)
      expect(chat.tool_options).to include(concurrency: :threads, workers: 4)
    end

    it 'carries over to a copy of the chat' do
      expect(chat.with_tool_options(workers: 4).dup.tool_options[:workers]).to eq(4)
    end

    it 'runs every call of a response, no more than the workers at once' do
      chat.with_tool_options(concurrency: :threads, workers: 2)
      allow(chat.provider).to receive(:complete).and_return(calls(6), answer)

      expect(chat.ask('Go').content).to eq('done')
      expect(running[:peak]).to eq(2)
      expect(chat.messages.count { |message| message.role == :tool && message.content == 'found' }).to eq(6)
    end

    it 'resets with nil' do
      chat.with_tool_options(concurrency: :threads, workers: 2).with_tool_options(workers: nil)
      allow(chat.provider).to receive(:complete).and_return(calls(6), answer)
      chat.ask('Go')

      expect(chat.tool_options[:workers]).to be_nil
      expect(running[:peak]).to be > 2
    end

    [0, -1, 1.5, '4', :many, true].each do |value|
      it "refuses #{value.inspect}" do
        expect { chat.with_tool_options(workers: value) }
          .to raise_error(ArgumentError, "Invalid workers value: #{value.inspect}. Valid values are positive integers")
      end
    end

    it 'sets the limit from an agent' do
      agent = Class.new(RubyLLM::Agent) { tool_options concurrency: :threads, workers: 3 }

      expect(agent.new.chat.tool_options).to include(concurrency: :threads, workers: 3)
    end
  end
end
