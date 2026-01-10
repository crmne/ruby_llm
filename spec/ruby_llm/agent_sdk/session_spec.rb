# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::Session do
  let(:messages) do
    [
      RubyLLM::AgentSDK::Message.new(type: 'user', content: 'Hello'),
      RubyLLM::AgentSDK::Message.new(type: 'assistant', content: 'Hi there'),
      RubyLLM::AgentSDK::Message.new(
        type: 'result',
        session_id: 'abc123',
        cost_usd: 0.05,
        input_tokens: 100,
        output_tokens: 50
      )
    ]
  end

  describe '#initialize' do
    it 'stores id and history' do
      session = described_class.new(id: 'test123', history: messages)
      expect(session.id).to eq('test123')
      expect(session.history).to eq(messages)
    end

    it 'defaults history to empty array' do
      session = described_class.new(id: 'test')
      expect(session.history).to eq([])
    end
  end

  describe '#last_message' do
    it 'returns the last message' do
      session = described_class.new(id: 'test', history: messages)
      expect(session.last_message).to eq(messages.last)
    end

    it 'returns nil for empty history' do
      session = described_class.new(id: 'test')
      expect(session.last_message).to be_nil
    end
  end

  describe '#last_result' do
    it 'returns the last result message' do
      session = described_class.new(id: 'test', history: messages)
      expect(session.last_result.result?).to be true
    end
  end

  describe '#assistant_messages' do
    it 'filters assistant messages' do
      session = described_class.new(id: 'test', history: messages)
      expect(session.assistant_messages.all?(&:assistant?)).to be true
    end
  end

  describe '#user_messages' do
    it 'filters user messages' do
      session = described_class.new(id: 'test', history: messages)
      expect(session.user_messages.all?(&:user?)).to be true
    end
  end

  describe '#total_cost_usd' do
    it 'sums cost from result messages' do
      session = described_class.new(id: 'test', history: messages)
      expect(session.total_cost_usd).to eq(0.05)
    end
  end

  describe '#total_input_tokens' do
    it 'sums input tokens from results' do
      session = described_class.new(id: 'test', history: messages)
      expect(session.total_input_tokens).to eq(100)
    end
  end

  describe '#total_output_tokens' do
    it 'sums output tokens from results' do
      session = described_class.new(id: 'test', history: messages)
      expect(session.total_output_tokens).to eq(50)
    end
  end

  describe '#turns' do
    it 'counts result messages' do
      session = described_class.new(id: 'test', history: messages)
      expect(session.turns).to eq(1)
    end
  end

  describe '#empty?' do
    it 'returns true for empty history' do
      session = described_class.new(id: 'test')
      expect(session.empty?).to be true
    end

    it 'returns false for non-empty history' do
      session = described_class.new(id: 'test', history: messages)
      expect(session.empty?).to be false
    end
  end

  describe '#to_h' do
    it 'returns serializable hash' do
      session = described_class.new(id: 'test123', history: messages)
      hash = session.to_h
      expect(hash[:id]).to eq('test123')
      expect(hash[:turns]).to eq(1)
      expect(hash[:total_cost_usd]).to eq(0.05)
      expect(hash[:message_count]).to eq(3)
    end
  end

  describe '.from_h' do
    it 'creates session from hash' do
      hash = {
        id: 'restored',
        history: [{ type: 'assistant', content: 'Hi' }]
      }
      session = described_class.from_h(hash)
      expect(session.id).to eq('restored')
      expect(session.history.first).to be_a(RubyLLM::AgentSDK::Message)
    end
  end
end

RSpec.describe RubyLLM::AgentSDK::SessionStore do
  let(:store) { described_class.new }
  let(:session) { RubyLLM::AgentSDK::Session.new(id: 'test123', history: []) }

  describe '#save and #load' do
    it 'stores session in memory' do
      store.save(session)
      loaded = store.load('test123')
      expect(loaded).to eq(session)
    end
  end

  describe '#delete' do
    it 'removes session from memory' do
      store.save(session)
      store.delete('test123')
      expect(store.load('test123')).to be_nil
    end
  end

  describe '#list' do
    it 'returns all session ids' do
      store.save(session)
      store.save(RubyLLM::AgentSDK::Session.new(id: 'another'))
      expect(store.list).to contain_exactly('test123', 'another')
    end
  end

  describe '#exist?' do
    it 'returns true for existing sessions' do
      store.save(session)
      expect(store.exist?('test123')).to be true
    end

    it 'returns false for unknown sessions' do
      expect(store.exist?('unknown')).to be false
    end
  end
end
