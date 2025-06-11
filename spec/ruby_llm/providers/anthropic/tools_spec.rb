# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::Tools do
  let(:tools) { described_class }

  describe '.format_tool_call' do
    let(:msg) do
      instance_double(Message,
                      content: 'Some content',
                      tool_calls: {
                        'tool_123' => instance_double(ToolCall,
                                                      id: 'tool_123',
                                                      name: 'test_tool',
                                                      arguments: { 'arg1' => 'value1' })
                      })
    end

    it 'formats a message with content and tool call' do # rubocop:disable RSpec/ExampleLength
      result = tools.format_tool_call(msg)

      expect(result).to eq({
                             role: 'assistant',
                             content: [
                               { type: 'text', text: 'Some content' },
                               {
                                 type: 'tool_use',
                                 id: 'tool_123',
                                 name: 'test_tool',
                                 input: { 'arg1' => 'value1' }
                               }
                             ]
                           })
    end

    context 'when message has no content' do
      let(:msg) do
        instance_double(Message,
                        content: nil,
                        tool_calls: {
                          'tool_123' => instance_double(ToolCall,
                                                        id: 'tool_123',
                                                        name: 'test_tool',
                                                        arguments: { 'arg1' => 'value1' })
                        })
      end

      it 'formats a message with only tool call' do # rubocop:disable RSpec/ExampleLength
        result = tools.format_tool_call(msg)

        expect(result).to eq({
                               role: 'assistant',
                               content: [
                                 {
                                   type: 'tool_use',
                                   id: 'tool_123',
                                   name: 'test_tool',
                                   input: { 'arg1' => 'value1' }
                                 }
                               ]
                             })
      end
    end

    context 'when message has empty content' do
      let(:msg) do
        instance_double(Message,
                        content: '',
                        tool_calls: {
                          'tool_123' => instance_double(ToolCall,
                                                        id: 'tool_123',
                                                        name: 'test_tool',
                                                        arguments: { 'arg1' => 'value1' })
                        })
      end

      it 'formats a message with only tool call' do # rubocop:disable RSpec/ExampleLength
        result = tools.format_tool_call(msg)

        expect(result).to eq({
                               role: 'assistant',
                               content: [
                                 {
                                   type: 'tool_use',
                                   id: 'tool_123',
                                   name: 'test_tool',
                                   input: { 'arg1' => 'value1' }
                                 }
                               ]
                             })
      end
    end
  end

  describe '.format_tool_result' do
    let(:msg) do
      instance_double(Message,
                      tool_call_id: 'tool_123',
                      content: 'Tool result')
    end

    it 'formats a tool result message' do # rubocop:disable RSpec/ExampleLength
      result = tools.format_tool_result(msg)

      expect(result).to eq({
                             role: 'user',
                             content: [
                               {
                                 type: 'tool_result',
                                 tool_use_id: 'tool_123',
                                 content: 'Tool result'
                               }
                             ]
                           })
    end
  end
end
