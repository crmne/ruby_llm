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
    it 'sums each count across attempts and skips missing attempts' do
      tokens = described_class.aggregate([nil, described_class.new(input: 10, output: 2), nil,
                                          described_class.new(input: 5, reported_cost: 0.01)])

      expect(tokens.input).to eq(15)
      expect(tokens.output).to eq(2)
      expect(tokens.thinking).to be_nil
      expect(tokens.reported_cost).to eq(0.01)
      expect(tokens.cache_write_by_ttl).to be_nil
    end

    it 'returns empty counts for no attempts' do
      expect(described_class.aggregate(nil).to_h).to eq({})
    end

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

  describe '#without_reported_cost' do
    it 'keeps every count and drops only the reported cost' do
      tokens = described_class.new(input: 10, output: 2, cache_read: 3, cache_write: 4, thinking: 1,
                                   cache_write_by_ttl: { '1h' => 4 }, server_tool_use: { 'web_search_requests' => 1 },
                                   reported_cost: 0.01)

      stripped = tokens.without_reported_cost

      expect(stripped.to_h).to eq(tokens.to_h)
      expect(stripped.reported_cost).to be_nil
      expect(tokens.reported_cost).to eq(0.01)
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
