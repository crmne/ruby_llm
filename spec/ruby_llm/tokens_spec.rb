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
  end
end
