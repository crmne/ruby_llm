# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::Stream do
  describe '.parse' do
    it 'parses JSON into Message' do
      json = '{"type":"assistant","content":"Hello"}'
      message = described_class.parse(json)
      expect(message).to be_a(RubyLLM::AgentSDK::Message)
      expect(message.type).to eq(:assistant)
      expect(message.content).to eq('Hello')
    end

    it 'returns nil for empty input' do
      expect(described_class.parse(nil)).to be_nil
      expect(described_class.parse('')).to be_nil
    end

    it 'raises JSONDecodeError for invalid JSON' do
      expect {
        described_class.parse('not valid json')
      }.to raise_error(RubyLLM::AgentSDK::JSONDecodeError)
    end

    it 'handles complex nested JSON' do
      json = '{"type":"tool_use","tool_use":[{"name":"Read","input":{"file":"test.rb"}}]}'
      message = described_class.parse(json)
      expect(message.type).to eq(:tool_use)
      expect(message.tool_calls).to be_an(Array)
      expect(message.tool_calls.first[:name]).to eq('Read')
    end
  end

  describe '.oj_available?' do
    it 'returns boolean' do
      expect(described_class.oj_available?).to be(true).or be(false)
    end
  end
end
