# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::Message do
  describe '#initialize' do
    it 'stores data and extracts type' do
      msg = described_class.new(type: 'assistant', content: 'Hello')
      expect(msg.type).to eq(:assistant)
      expect(msg.content).to eq('Hello')
    end

    it 'handles nil input' do
      msg = described_class.new(nil)
      expect(msg.type).to eq(:unknown)
      expect(msg.data).to eq({})
    end
  end

  describe 'type predicates' do
    it 'returns true for matching type' do
      msg = described_class.new(type: 'assistant')
      expect(msg.assistant?).to be true
      expect(msg.user?).to be false
      expect(msg.system?).to be false
    end

    it 'handles all message types' do
      described_class::MESSAGE_TYPES.each do |type|
        msg = described_class.new(type: type.to_s)
        expect(msg.send(:"#{type}?")).to be true
      end
    end
  end

  describe '#content' do
    it 'handles content field' do
      msg = described_class.new(content: 'test')
      expect(msg.content).to eq('test')
    end

    it 'handles text field' do
      msg = described_class.new(text: 'test')
      expect(msg.content).to eq('test')
    end

    it 'handles message field' do
      msg = described_class.new(message: 'test')
      expect(msg.content).to eq('test')
    end
  end

  describe '#session_id' do
    it 'handles snake_case' do
      msg = described_class.new(session_id: 'abc123')
      expect(msg.session_id).to eq('abc123')
    end

    it 'handles camelCase' do
      msg = described_class.new(sessionId: 'xyz789')
      expect(msg.session_id).to eq('xyz789')
    end
  end

  describe '#cost_usd' do
    it 'handles snake_case' do
      msg = described_class.new(cost_usd: 0.05)
      expect(msg.cost_usd).to eq(0.05)
    end

    it 'handles camelCase' do
      msg = described_class.new(costUsd: 0.10)
      expect(msg.cost_usd).to eq(0.10)
    end
  end

  describe '#role' do
    it 'returns role as symbol' do
      msg = described_class.new(role: 'assistant')
      expect(msg.role).to eq(:assistant)
    end

    it 'returns nil for missing role' do
      msg = described_class.new({})
      expect(msg.role).to be_nil
    end
  end

  describe '#tool_calls' do
    it 'returns tool_use array' do
      msg = described_class.new(tool_use: [{ name: 'Read' }])
      expect(msg.tool_calls).to eq([{ name: 'Read' }])
    end

    it 'returns empty array when no tool calls' do
      msg = described_class.new({})
      expect(msg.tool_calls).to eq([])
    end
  end

  describe 'type inference' do
    it 'infers assistant type from role' do
      msg = described_class.new(role: 'assistant', content: 'Hi')
      expect(msg.type).to eq(:assistant)
    end

    it 'infers user type from role' do
      msg = described_class.new(role: 'user', content: 'Hi')
      expect(msg.type).to eq(:user)
    end

    it 'infers tool_use from presence of tool_use field' do
      msg = described_class.new(tool_use: [{ name: 'Read' }])
      expect(msg.type).to eq(:tool_use)
    end

    it 'infers result from session_id presence' do
      msg = described_class.new(session_id: 'abc')
      expect(msg.type).to eq(:result)
    end

    it 'infers error from error field presence' do
      msg = described_class.new(error: 'something went wrong')
      expect(msg.type).to eq(:error)
    end
  end

  describe 'dynamic attribute access' do
    it 'allows access to arbitrary fields' do
      msg = described_class.new(custom_field: 'value', another: 123)
      expect(msg.custom_field).to eq('value')
      expect(msg.another).to eq(123)
    end

    it 'responds to arbitrary fields' do
      msg = described_class.new(custom_field: 'value')
      expect(msg.respond_to?(:custom_field)).to be true
      expect(msg.respond_to?(:missing)).to be false
    end
  end

  describe '#to_h' do
    it 'returns data as hash' do
      msg = described_class.new(type: 'assistant', content: 'Hi')
      hash = msg.to_h
      expect(hash[:type]).to eq('assistant')
      expect(hash[:content]).to eq('Hi')
    end
  end
end
