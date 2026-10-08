# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Tokens do
  describe '#server_tool_use' do
    it 'counts each tool that ran under a String key' do
      tokens = described_class.new(server_tool_use: { web_search_requests: 2, 'web_fetch_requests' => 1 })

      expect(tokens.server_tool_use).to eq('web_search_requests' => 2, 'web_fetch_requests' => 1)
    end

    it 'leaves out tools that did not run' do
      tokens = described_class.new(server_tool_use: { 'web_search_requests' => 1, 'web_fetch_requests' => 0 })

      expect(tokens.server_tool_use).to eq('web_search_requests' => 1)
    end

    it 'is nil when no tool ran' do
      expect(described_class.new(server_tool_use: { 'web_search_requests' => 0 }).server_tool_use).to be_nil
      expect(described_class.new(input: 10).server_tool_use).to be_nil
    end
  end

  describe '.aggregate' do
    it 'sums server tool counts across attempts' do
      tokens = described_class.aggregate(
        [
          described_class.new(server_tool_use: { 'web_search_requests' => 1 }),
          described_class.new(input: 10),
          described_class.new(server_tool_use: { 'web_search_requests' => 2, 'web_fetch_requests' => 1 })
        ]
      )

      expect(tokens.server_tool_use).to eq('web_search_requests' => 3, 'web_fetch_requests' => 1)
    end

    it 'sums cache writes by lifetime across attempts' do
      tokens = described_class.aggregate(
        [
          described_class.new(cache_write: 10, cache_write_by_ttl: { '1h' => 10 }),
          described_class.new(cache_write: 5, cache_write_by_ttl: { '5m' => 2, '1h' => 3 })
        ]
      )

      expect(tokens.cache_write_by_ttl).to eq('1h' => 13, '5m' => 2)
    end
  end

  describe '#cache_write_by_ttl' do
    it 'leaves out lifetimes with no writes' do
      tokens = described_class.new(cache_write_by_ttl: { '5m' => 0, :'1h' => 20 })

      expect(tokens.cache_write_by_ttl).to eq('1h' => 20)
      expect(described_class.new(cache_write_by_ttl: { '5m' => 0 }).cache_write_by_ttl).to be_nil
    end

    it 'survives a round trip through a serialized message' do
      message = RubyLLM::Message.new(role: :assistant, content: 'Hi', cache_write_tokens: 20,
                                     cache_write_tokens_by_ttl: { '1h' => 20 })

      restored = RubyLLM::Message.new(message.to_h)

      expect(restored.tokens.cache_write_by_ttl).to eq('1h' => 20)
    end
  end
end
