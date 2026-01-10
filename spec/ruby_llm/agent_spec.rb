# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent'

RSpec.describe RubyLLM::Agent do
  describe '#initialize' do
    it 'creates an agent with default settings' do
      agent = described_class.new
      expect(agent.max_turns).to eq(10)
      expect(agent.chat).to be_a(RubyLLM::Chat)
    end

    it 'accepts custom max_turns' do
      agent = described_class.new(max_turns: 5)
      expect(agent.max_turns).to eq(5)
    end
  end

  describe '#with_tool' do
    it 'adds a tool and returns self' do
      agent = described_class.new
      result = agent.with_tool(RubyLLM::Agent::Tools::Read)
      expect(result).to eq(agent)
    end
  end

  describe '#with_tools' do
    it 'adds multiple tools' do
      agent = described_class.new
        .with_tools(RubyLLM::Agent::Tools::Read, RubyLLM::Agent::Tools::Glob)

      expect(agent.chat.tools.keys).to include(:'ruby_llm--agent--tools--read')
    end

    it 'accepts array syntax' do
      agent = described_class.new
        .with_tools(RubyLLM::Agent::Tools[:safe])

      expect(agent.chat.tools.size).to eq(3)
    end
  end

  describe '#with_permission' do
    it 'sets permission mode' do
      agent = described_class.new.with_permission(:deny_all)
      expect(agent.permissions.mode).to eq(:deny_all)
    end
  end

  describe '#before_tool' do
    it 'adds a pre-tool hook' do
      called = false
      agent = described_class.new
        .before_tool('Bash') { called = true }

      # Hook is registered
      expect(agent.hooks).to be_a(RubyLLM::Agent::Hooks)
    end
  end

  describe '#after_tool' do
    it 'adds a post-tool hook' do
      agent = described_class.new
        .after_tool('Bash') { |ctx| ctx }

      expect(agent.hooks).to be_a(RubyLLM::Agent::Hooks)
    end
  end

  describe '#with_max_turns' do
    it 'sets max turns and returns self' do
      agent = described_class.new
      result = agent.with_max_turns(20)
      expect(result).to eq(agent)
      expect(agent.max_turns).to eq(20)
    end
  end

  describe '#with_model' do
    it 'sets the model and returns self' do
      agent = described_class.new
      result = agent.with_model('gpt-4o-mini')
      expect(result).to eq(agent)
    end
  end

  describe '#with_temperature' do
    it 'sets temperature and returns self' do
      agent = described_class.new
      result = agent.with_temperature(0.5)
      expect(result).to eq(agent)
    end
  end

  describe '#on' do
    it 'registers event callbacks' do
      events = []
      agent = described_class.new
        .on(:message) { |e| events << e }
        .on(:tool_call) { |e| events << e }

      # Callbacks are registered (tested via run in integration)
      expect(agent).to be_a(described_class)
    end
  end

  describe '#messages' do
    it 'returns chat messages' do
      agent = described_class.new
      expect(agent.messages).to eq([])
    end
  end
end

RSpec.describe 'RubyLLM.agent' do
  it 'creates an agent' do
    agent = RubyLLM.agent
    expect(agent).to be_a(RubyLLM::Agent)
  end

  it 'accepts options' do
    agent = RubyLLM.agent(max_turns: 5)
    expect(agent.max_turns).to eq(5)
  end
end
