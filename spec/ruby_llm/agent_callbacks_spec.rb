# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  def answer(content = 'Done')
    RubyLLM::Message.new(role: :assistant, content:, input_tokens: 1, output_tokens: 1)
  end

  def stub_answers(chat, *answers)
    allow(chat.provider).to receive(:complete).and_return(*answers)
  end

  it 'runs a method named in a callback macro on the agent, with the callback arguments' do
    agent_class = Class.new(described_class) do
      after_message :remember

      def seen = @seen ||= []

      private

      def remember(message) = seen << message.content
    end
    agent = agent_class.new
    stub_answers(agent.chat, answer('Hello'))

    agent.ask('Hi')

    expect(agent.seen).to eq(['Hello'])
  end

  it 'runs a block in the agent, and a method that takes no arguments' do
    events = []
    agent_class = Class.new(described_class) do
      before_message { events << [:before, self.class] }
      after_message :tick

      define_method(:tick) { events << :tick }
    end
    agent = agent_class.new
    stub_answers(agent.chat, answer)

    agent.ask('Hi')

    expect(events).to eq([[:before, agent_class], :tick])
  end

  it 'guards a callback with if: and unless:, as a method name or a block' do
    events = []
    agent_class = Class.new(described_class) do
      inputs :loud

      after_message(if: :loud) { |message| events << [:if, message.content] }
      after_message(unless: -> { loud }) { |message| events << [:unless, message.content] }
      after_message(if: ->(message) { message.content == 'Skip' }) { events << :never }
    end
    loud = agent_class.new(loud: true)
    quiet = agent_class.new(loud: false)
    stub_answers(loud.chat, answer('A'))
    stub_answers(quiet.chat, answer('B'))

    loud.ask('Hi')
    quiet.ask('Hi')

    expect(events).to eq([[:if, 'A'], [:unless, 'B']])
  end

  it 'covers the tool hooks' do
    events = []
    echo = Class.new(RubyLLM::Tool) do
      description 'Echoes'
      define_method(:name) { 'echo' }
      define_method(:execute) { 'echoed' }
    end
    agent_class = Class.new(described_class) do
      tools echo
      before_tool_call { |call| events << [:call, call.name] }
      after_tool_result { |result| events << [:result, result] }
    end
    agent = agent_class.new
    call = RubyLLM::ToolCall.new(id: 'call_1', name: 'echo', arguments: {})
    stub_answers(agent.chat, RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { 'call_1' => call }),
                 answer)

    agent.ask('Echo')

    expect(events).to eq([[:call, 'echo'], [:result, 'echoed']])
  end

  it 'inherits callbacks, and keeps a subclass callback to the subclass' do
    events = []
    parent = Class.new(described_class) do
      after_message { events << :parent }
    end
    child = Class.new(parent) { after_message { events << :child } }
    parent_agent = parent.new
    child_agent = child.new
    stub_answers(parent_agent.chat, answer)
    stub_answers(child_agent.chat, answer)

    parent_agent.ask('Hi')
    child_agent.ask('Hi')

    expect(events).to eq(%i[parent parent child])
  end

  it 'applies callbacks to a chat the agent builds with ::chat' do
    events = []
    agent_class = Class.new(described_class) do
      after_message :record

      define_method(:record) { |message| events << [self.class, message.content] }
    end
    chat = agent_class.chat
    stub_answers(chat, answer('Hello'))

    chat.ask('Hi')

    expect(events).to eq([[agent_class, 'Hello']])
  end

  it 'registers callbacks once when an agent wraps a chat it already configured, on the newest agent' do
    events = []
    agent_class = Class.new(described_class) do
      inputs :name
      after_message { events << name }
    end
    chat = agent_class.chat(name: 'first')
    agent = agent_class.new(chat:, name: 'second')
    stub_answers(chat, answer)

    agent.ask('Hi')

    expect(events).to eq(['second'])
  end

  it 'refuses a callback with both a method name and a block, or neither, and unknown options' do
    agent_class = Class.new(described_class)

    expect { agent_class.after_message(:record) { nil } }.to raise_error(ArgumentError, /method name or a block/)
    expect { agent_class.after_message }.to raise_error(ArgumentError, /method name or a block/)
    expect { agent_class.after_message(:record, when: :x) }.to raise_error(ArgumentError, /if: and unless:/)
  end
end
