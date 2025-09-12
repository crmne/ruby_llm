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

  describe '#convert_role' do
    it 'maps system/user/tool to user and assistant stays assistant' do
      expect(provider.send(:convert_role, :system)).to eq('user')
      expect(provider.send(:convert_role, :user)).to eq('user')
      expect(provider.send(:convert_role, :tool)).to eq('user')
      expect(provider.send(:convert_role, :assistant)).to eq('assistant')
    end
  end

  describe '#format_basic_message' do
    it 'formats content for converse' do
      msg = RubyLLM::Message.new(role: :user, content: 'hi')
      formatted = provider.send(:format_basic_message, msg)
      expect(formatted[:role]).to eq('user')
      expect(formatted[:content]).to eq([{ 'text' => 'hi' }])
    end
  end

  describe '#format_tool_call' do
    it 'skips when tool_calls are empty and logs' do
      msg = RubyLLM::Message.new(role: :assistant, content: '', tool_calls: {})
      allow(RubyLLM.logger).to receive(:warn)
      expect(provider.send(:format_tool_call, msg)).to be_nil
      expect(RubyLLM.logger).to have_received(:warn).with(/tool_calls empty/)
    end

    it 'filters out calls with missing id and warns if all removed' do
      calls = {
        a: RubyLLM::ToolCall.new(id: '', name: 'x', arguments: {}),
        b: RubyLLM::ToolCall.new(id: nil, name: 'y', arguments: {})
      }
      msg = RubyLLM::Message.new(role: :assistant, content: '', tool_calls: calls)
      allow(RubyLLM.logger).to receive(:warn)
      expect(provider.send(:format_tool_call, msg)).to be_nil
      expect(RubyLLM.logger).to have_received(:warn).with(/missing ids/)
    end

    it 'builds toolUse content blocks' do
      calls = {
        a: RubyLLM::ToolCall.new(id: 'id1', name: 'search', arguments: { q: 'ruby' }),
        b: RubyLLM::ToolCall.new(id: 'id2', name: 'calc', arguments: { x: 1 })
      }
      msg = RubyLLM::Message.new(role: :assistant, content: '', tool_calls: calls)
      result = provider.send(:format_tool_call, msg)
      expect(result[:role]).to eq('assistant')
      expect(result[:content]).to contain_exactly(
        { 'toolUse' => { 'toolUseId' => 'id1', 'name' => 'search', 'input' => { q: 'ruby' } } },
        { 'toolUse' => { 'toolUseId' => 'id2', 'name' => 'calc', 'input' => { x: 1 } } }
      )
    end
  end

  describe '#format_tool_result' do
    it 'skips when tool_call_id missing' do
      msg = RubyLLM::Message.new(role: :tool, content: 'ok', tool_call_id: '')
      allow(RubyLLM.logger).to receive(:warn)
      expect(provider.send(:format_tool_result, msg)).to be_nil
      expect(RubyLLM.logger).to have_received(:warn).with(/tool_call_id is null or empty/)
    end

    it 'formats tool result content' do
      msg = RubyLLM::Message.new(role: :tool, content: 'ok', tool_call_id: 'tu_1')
      result = provider.send(:format_tool_result, msg)
      expect(result[:role]).to eq('user')
      expect(result[:content]).to eq([
                                       { 'toolResult' => { 'toolUseId' => 'tu_1', 'content' => [{ 'text' => 'ok' }] } }
                                     ])
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

  describe '#validate_no_tool_use_and_result!' do
    it 'raises when a message contains both toolUse and toolResult' do
      msg = { role: 'assistant', content: [{ 'toolUse' => {} }, { 'toolResult' => {} }] }
      expect do
        provider.send(:validate_no_tool_use_and_result!, [msg])
      end.to raise_error(/Message cannot contain both/)
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
