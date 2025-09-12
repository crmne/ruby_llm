# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Streaming do
  include_context 'with configured RubyLLM'

  let(:provider) do
    RubyLLM::Providers::Bedrock.new(RubyLLM.config).tap do |p|
      p.extend(described_class)
    end
  end

  describe 'payload processing' do
    it 'yields chunks for content start/delta and accumulates tool calls and usage' do
      provider.instance_variable_set(:@model_id, 'anthropic.claude-3-sonnet')
      provider.send(:initialize_tool_call_accumulator)

      chunks = []

      # Simulate headers for event types
      headers_start = { ':event-type' => 'contentBlockStart' }
      headers_delta = { ':event-type' => 'contentBlockDelta' }
      headers_tool_start = { ':event-type' => 'contentBlockStart' }
      headers_tool_delta = { ':event-type' => 'contentBlockDelta' }
      headers_tool_stop = { ':event-type' => 'contentBlockStop' }
      headers_metadata = { ':event-type' => 'metadata' }

      # content start
      json1 = { type: 'contentBlockStart', start: { text: '' } }.to_json
      provider.send(:process_payload_with_headers, json1, headers_start) { |c| chunks << c }

      # text delta
      json2 = { type: 'contentBlockDelta', delta: { text: 'Hello' } }.to_json
      provider.send(:process_payload_with_headers, json2, headers_delta) { |c| chunks << c }

      # tool use start
      json3 = { type: 'contentBlockStart', start: { toolUse: { toolUseId: 'tu_1', name: 'search' } } }.to_json
      provider.send(:process_payload_with_headers, json3, headers_tool_start) { |c| chunks << c }

      # tool use delta (arguments stream)
      json4 = { type: 'contentBlockDelta', delta: { toolUse: { input: '{"q":"ruby"}' } } }.to_json
      provider.send(:process_payload_with_headers, json4, headers_tool_delta) { |c| chunks << c }

      # tool use stop
      json5 = { type: 'contentBlockStop' }.to_json
      provider.send(:process_payload_with_headers, json5, headers_tool_stop) { |c| chunks << c }

      # metadata with usage
      json6 = { type: 'metadata', usage: { 'inputTokens' => 5, 'outputTokens' => 9 } }.to_json
      provider.send(:process_payload_with_headers, json6, headers_metadata) { |c| chunks << c }

      # We should have yielded for start (no content) and delta (with content)
      expect(chunks.length).to be >= 2
      expect(chunks.any? { |c| c.content == '' }).to be true
      expect(chunks.any? { |c| c.content == 'Hello' }).to be true

      # Tool call accumulated
      calls = provider.send(:accumulated_tool_calls)
      expect(calls.length).to eq(1)
      expect(calls.first).to have_attributes(id: 'tu_1', name: 'search', arguments: { 'q' => 'ruby' })

      # Usage captured
      usage = provider.send(:token_usage)
      expect(usage['inputTokens']).to eq(5)
      expect(usage['outputTokens']).to eq(9)
    end
  end

  describe RubyLLM::Providers::Bedrock::Streaming::Messages do
    let(:mod) do
      Module.new do
        include RubyLLM::Providers::Bedrock::Streaming::Messages
        include RubyLLM::Providers::Bedrock::Streaming::Prelude
        include RubyLLM::Providers::Bedrock::Streaming::Payload
      end
    end

    it 'validates payload structure detection' do
      obj = Object.new.extend(mod)
      payload = '{"type":"x"}'
      json = obj.send(:extract_json_payload, "abc#{payload}def")
      expect(json).to eq(payload)

      # valid_payload? requires braces
      expect(obj.send(:valid_payload?, 'nope')).to be false
    end
  end
end
