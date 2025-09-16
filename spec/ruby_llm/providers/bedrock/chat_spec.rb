# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Chat do
  include_context 'with configured RubyLLM'

  let(:provider) do
    RubyLLM::Providers::Bedrock.new(RubyLLM.config).tap do |p|
      p.extend(described_class)
      p.extend(RubyLLM::Providers::Bedrock::Tools)
      p.extend(RubyLLM::Providers::Bedrock::Media)
    end
  end

  describe '#format_role' do
    it 'maps system/user/tool to user and assistant stays assistant' do
      expect(provider.send(:format_role, :system)).to eq('user')
      expect(provider.send(:format_role, :user)).to eq('user')
      expect(provider.send(:format_role, :tool)).to eq('user')
      expect(provider.send(:format_role, :assistant)).to eq('assistant')
    end
  end

  describe '#merge_consecutive_tool_result_messages' do
    it 'merges multiple consecutive toolResult messages into one user message' do
      messages = [
        { role: 'assistant', content: [{ 'text' => 'Hello' }] },
        { role: 'assistant', content: [{ 'toolResult' => { 'toolUseId' => 'a', 'content' => [{ 'text' => '1' }] } }] },
        { role: 'assistant', content: [{ 'toolResult' => { 'toolUseId' => 'b', 'content' => [{ 'text' => '2' }] } }] },
        { role: 'assistant', content: [{ 'text' => 'Next' }] }
      ]

      merged = provider.send(:merge_consecutive_tool_result_messages, messages)
      expect(merged.length).to eq(3)
      expect(merged[1][:role]).to eq('user')
      expect(merged[1][:content].length).to eq(2)
    end
  end

  describe '#parse_completion_response' do
    it 'builds message with tokens and tool calls' do
      provider.instance_variable_set(:@model_id, 'anthropic.claude-3-sonnet')
      body = {
        'output' => {
          'message' => {
            'content' => [
              { 'text' => 'Hello' },
              { 'toolUse' => { 'toolUseId' => 'tu_1', 'name' => 'search', 'input' => { 'q' => 'ruby' } } }
            ]
          }
        },
        'usage' => { 'inputTokens' => 10, 'outputTokens' => 20 }
      }
      response = instance_double(Faraday::Response, body: body)

      message = provider.send(:parse_completion_response, response)
      expect(message).to be_a(RubyLLM::Message)
      expect(message.content).to eq('Hello')
      expect(message.input_tokens).to eq(10)
      expect(message.output_tokens).to eq(20)
      expect(message.tool_calls).to be_a(Hash)
      expect(message.model_id).to eq('anthropic.claude-3-sonnet')
    end
  end

  describe '#render_payload' do
    it 'builds converse payload with system, tools and temperature' do
      model = RubyLLM::Model::Info.new(id: 'anthropic.claude-3-sonnet', name: 'Claude', provider: 'bedrock')

      sys = RubyLLM::Message.new(role: :system, content: 'You are helpful.')
      usr = RubyLLM::Message.new(role: :user, content: 'hi')
      tool = Class.new do
        def name = 'search'
        def description = 'Search the web'
        def parameters = {}
      end.new

      payload = provider.send(:render_payload, [sys, usr], tools: { search: tool }, temperature: 0.3, model:)

      expect(payload[:messages].first).to eq({ role: 'user', content: [{ 'text' => 'You are helpful.' }] })
      expect(payload[:messages].last[:content]).to eq([{ 'text' => 'hi' }])
      expect(payload[:toolConfig]).to be_present
      expect(payload[:inferenceConfig][:temperature]).to eq(0.3)
    end
  end
end
