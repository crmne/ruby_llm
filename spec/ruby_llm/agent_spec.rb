# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  it 'builds a configured plain chat via .chat with runtime inputs' do
    tool_class = Class.new(RubyLLM::Tool) do
      def name = 'echo_tool'
    end

    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
      inputs :display_name
      instructions { "Hello #{display_name}" }
      tools { [tool_class.new] }
      params { { max_tokens: 12 } }
    end

    chat = agent_class.chat(display_name: 'Ava')

    expect(chat.messages.first.role).to eq(:system)
    expect(chat.messages.first.content).to eq('Hello Ava')
    expect(chat.tools.keys).to include(:echo_tool)
    expect(chat.params).to eq(max_tokens: 12)
  end

  it 'exposes RubyLLM::Chat as chat in execution context for .chat' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
      instructions { chat.class.name }
    end

    chat = agent_class.chat
    expect(chat.messages.first.content).to eq('RubyLLM::Chat')
  end

  it 'supports instructions with no args even when no default prompt exists' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
      instructions
    end

    chat = agent_class.chat
    expect(chat.messages).to be_empty
  end

  it 'can ask using the first configured chat model' do
    model_info = CHAT_MODELS.first

    agent_class = Class.new(RubyLLM::Agent) do
      model model_info[:model], provider: model_info[:provider]
      instructions 'Answer questions clearly.'
    end

    stub_const('SpecChatAgent', agent_class)

    response = SpecChatAgent.new.ask("What's 2 + 2?")
    expect(response.content).to include('4')
    expect(response.role).to eq(:assistant)
  end

  it 'delegates add_message to the underlying chat interface' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
    end

    agent = agent_class.new
    message = agent.add_message(role: :user, content: 'Hello')

    expect(message.role).to eq(:user)
    expect(message.content).to eq('Hello')
    expect(agent.chat.messages.last).to eq(message)
  end

  it 'exposes messages like RubyLLM::Chat' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
    end

    agent = agent_class.new
    agent.add_message(role: :user, content: 'First')

    expect(agent.messages).to eq(agent.chat.messages)
    expect(agent.messages.last.content).to eq('First')
  end

  it 'delegates callback hooks to the underlying chat' do
    fake_chat = Class.new do
      attr_reader :events

      def initialize
        @events = []
      end

      def on_new_message(&)
        @events << :new_message
        self
      end

      def on_end_message(&)
        @events << :end_message
        self
      end

      def on_tool_call(&)
        @events << :tool_call
        self
      end

      def on_tool_result(&)
        @events << :tool_result
        self
      end
    end.new

    agent = Class.new(described_class).new(chat: fake_chat)

    expect(agent.on_new_message { :ok }).to eq(fake_chat)
    expect(agent.on_end_message { :ok }).to eq(fake_chat)
    expect(agent.on_tool_call { :ok }).to eq(fake_chat)
    expect(agent.on_tool_result { :ok }).to eq(fake_chat)
    expect(fake_chat.events).to eq(%i[new_message end_message tool_call tool_result])
  end

  it 'supports Enumerable by delegating each to chat' do
    fake_chat = Class.new do
      def each(&block)
        return enum_for(:each) unless block_given?

        %w[first second].each(&block)
      end
    end.new

    agent = Class.new(described_class).new(chat: fake_chat)
    expect(agent.map(&:upcase)).to eq(%w[FIRST SECOND])
  end

  describe 'fallback' do
    it 'stores and retrieves fallback config via class macro' do
      agent_class = Class.new(RubyLLM::Agent) do
        model 'gpt-4.1-nano'
        fallback 'claude-haiku-4-5-20251001', provider: :anthropic
      end

      expect(agent_class.fallback).to eq({ model: 'claude-haiku-4-5-20251001', provider: :anthropic })
    end

    it 'returns nil when no fallback is configured' do
      agent_class = Class.new(RubyLLM::Agent) do
        model 'gpt-4.1-nano'
      end

      expect(agent_class.fallback).to be_nil
    end

    it 'inherits fallback config to subclasses' do
      parent_class = Class.new(RubyLLM::Agent) do
        model 'gpt-4.1-nano'
        fallback 'claude-haiku-4-5-20251001', provider: :anthropic
      end

      child_class = Class.new(parent_class)

      expect(child_class.fallback).to eq({ model: 'claude-haiku-4-5-20251001', provider: :anthropic })
    end

    it 'does not affect parent when child overrides fallback' do
      parent_class = Class.new(RubyLLM::Agent) do
        model 'gpt-4.1-nano'
        fallback 'claude-haiku-4-5-20251001', provider: :anthropic
      end

      child_class = Class.new(parent_class) do
        fallback 'gpt-4.1-mini'
      end

      expect(parent_class.fallback).to eq({ model: 'claude-haiku-4-5-20251001', provider: :anthropic })
      expect(child_class.fallback).to eq({ model: 'gpt-4.1-mini', provider: nil })
    end

    it 'applies fallback to the underlying chat via .chat' do
      agent_class = Class.new(RubyLLM::Agent) do
        model 'gpt-4.1-nano'
        fallback 'claude-haiku-4-5-20251001', provider: :anthropic
      end

      chat = agent_class.chat
      fallback_config = chat.instance_variable_get(:@fallback)

      expect(fallback_config).to eq({ model: 'claude-haiku-4-5-20251001', provider: :anthropic })
    end

    it 'applies fallback to the underlying chat via .new' do
      agent_class = Class.new(RubyLLM::Agent) do
        model 'gpt-4.1-nano'
        fallback 'claude-haiku-4-5-20251001', provider: :anthropic
      end

      agent = agent_class.new
      fallback_config = agent.chat.instance_variable_get(:@fallback)

      expect(fallback_config).to eq({ model: 'claude-haiku-4-5-20251001', provider: :anthropic })
    end

    it 'does not apply fallback when none is configured' do
      agent_class = Class.new(RubyLLM::Agent) do
        model 'gpt-4.1-nano'
      end

      chat = agent_class.chat
      fallback_config = chat.instance_variable_get(:@fallback)

      expect(fallback_config).to be_nil
    end
  end
end
