# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Tools do
  describe '.parse_tool_calls' do
    it 'parses tool calls without thought signatures' do
      tool_calls = [
        {
          'id' => 'call_123',
          'function' => {
            'name' => 'weather',
            'arguments' => '{"location":"Berlin"}'
          }
        }
      ]

      result = described_class.parse_tool_calls(tool_calls)

      expect(result).to be_a(Hash)
      expect(result.size).to eq(1)
      expect(result['call_123'].name).to eq('weather')
      expect(result['call_123'].arguments).to eq({ 'location' => 'Berlin' })
      expect(result['call_123'].thought_signature).to be_nil
    end

    it 'extracts thought signatures from extra_content.google.thought_signature' do
      tool_calls = [
        {
          'id' => 'call_456',
          'function' => {
            'name' => 'weather',
            'arguments' => '{"location":"Paris"}'
          },
          'extra_content' => {
            'google' => {
              'thought_signature' => 'sig_abc123'
            }
          }
        }
      ]

      result = described_class.parse_tool_calls(tool_calls)

      expect(result['call_456'].thought_signature).to eq('sig_abc123')
    end

    it 'handles multiple tool calls with thought signatures' do
      tool_calls = [
        {
          'id' => 'call_1',
          'function' => { 'name' => 'tool_a', 'arguments' => '{}' },
          'extra_content' => { 'google' => { 'thought_signature' => 'sig_first' } }
        },
        {
          'id' => 'call_2',
          'function' => { 'name' => 'tool_b', 'arguments' => '{}' }
        }
      ]

      result = described_class.parse_tool_calls(tool_calls)

      expect(result['call_1'].thought_signature).to eq('sig_first')
      expect(result['call_2'].thought_signature).to be_nil
    end

    it 'returns nil for empty or nil input' do
      expect(described_class.parse_tool_calls(nil)).to be_nil
      expect(described_class.parse_tool_calls([])).to be_nil
    end
  end

  describe '.format_tool_calls' do
    it 'formats tool calls without thought signatures' do
      tool_call = RubyLLM::ToolCall.new(
        id: 'call_123',
        name: 'weather',
        arguments: { 'location' => 'Berlin' }
      )

      result = described_class.format_tool_calls({ 'call_123' => tool_call })

      expect(result).to eq([
                             {
                               id: 'call_123',
                               type: 'function',
                               function: {
                                 name: 'weather',
                                 arguments: '{"location":"Berlin"}'
                               }
                             }
                           ])
    end

    it 'includes extra_content.google.thought_signature when present' do
      tool_call = RubyLLM::ToolCall.new(
        id: 'call_456',
        name: 'weather',
        arguments: { 'location' => 'Paris' },
        thought_signature: 'sig_xyz789'
      )

      result = described_class.format_tool_calls({ 'call_456' => tool_call })

      expect(result).to eq([
                             {
                               id: 'call_456',
                               type: 'function',
                               function: {
                                 name: 'weather',
                                 arguments: '{"location":"Paris"}'
                               },
                               extra_content: {
                                 google: { thought_signature: 'sig_xyz789' }
                               }
                             }
                           ])
    end

    it 'formats multiple tool calls preserving their signatures' do
      tool_calls = {
        'call_1' => RubyLLM::ToolCall.new(
          id: 'call_1',
          name: 'tool_a',
          arguments: {},
          thought_signature: 'sig_first'
        ),
        'call_2' => RubyLLM::ToolCall.new(
          id: 'call_2',
          name: 'tool_b',
          arguments: {}
        )
      }

      result = described_class.format_tool_calls(tool_calls)

      first_call = result.find { |c| c[:id] == 'call_1' }
      second_call = result.find { |c| c[:id] == 'call_2' }

      expect(first_call[:extra_content]).to eq({ google: { thought_signature: 'sig_first' } })
      expect(second_call).not_to have_key(:extra_content)
    end

    it 'returns nil for empty or nil input' do
      expect(described_class.format_tool_calls(nil)).to be_nil
      expect(described_class.format_tool_calls({})).to be_nil
    end
  end

  describe '.extract_tool_call_thought_signature' do
    it 'extracts signature from nested structure' do
      tool_call = {
        'extra_content' => {
          'google' => {
            'thought_signature' => 'test_sig'
          }
        }
      }

      result = described_class.extract_tool_call_thought_signature(tool_call)
      expect(result).to eq('test_sig')
    end

    it 'returns nil when extra_content is missing' do
      tool_call = { 'id' => 'call_1' }

      result = described_class.extract_tool_call_thought_signature(tool_call)
      expect(result).to be_nil
    end

    it 'returns nil when google key is missing' do
      tool_call = { 'extra_content' => {} }

      result = described_class.extract_tool_call_thought_signature(tool_call)
      expect(result).to be_nil
    end

    it 'returns nil when thought_signature is missing' do
      tool_call = { 'extra_content' => { 'google' => {} } }

      result = described_class.extract_tool_call_thought_signature(tool_call)
      expect(result).to be_nil
    end
  end
end
