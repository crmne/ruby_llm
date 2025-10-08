# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Tools do
  let(:tools) { described_class }
  let(:tool_double) do
    Class.new do
      attr_reader :name, :description, :parameters

      def initialize
        param_struct = Struct.new(:type, :description, :required)
        @name = 'search'
        @description = 'Search the web'
        @parameters = {
          query: param_struct.new('string', 'The query', true),
          limit: param_struct.new('integer', 'Max results', false)
        }
      end
    end.new
  end

  describe '.tool_for' do
    it 'builds Bedrock toolSpec payload' do
      spec = described_class.tool_for(tool_double)

      expect(spec).to eq({
                           toolSpec: {
                             name: 'search',
                             description: 'Search the web',
                             inputSchema: {
                               json: {
                                 type: 'object',
                                 properties: {
                                   query: { type: 'string', description: 'The query' },
                                   limit: { type: 'integer', description: 'Max results' }
                                 },
                                 required: [:query]
                               }
                             }
                           }
                         })
    end
  end

  describe '.parse_tool_calls' do
    it 'parses toolUse blocks into ToolCall hash' do
      tool_use_blocks = [
        { 'toolUse' => { 'toolUseId' => 'tu_1', 'name' => 'search', 'input' => { 'query' => 'ruby' } } },
        { 'toolUse' => { 'id' => 'tu_2', 'name' => 'lookup', 'input' => { 'id' => 42 } } }
      ]

      calls = described_class.parse_tool_calls(tool_use_blocks)

      expect(calls.keys).to contain_exactly('tu_1', 'tu_2')
      expect(calls['tu_1']).to have_attributes(id: 'tu_1', name: 'search', arguments: { 'query' => 'ruby' })
      expect(calls['tu_2']).to have_attributes(id: 'tu_2', name: 'lookup', arguments: { 'id' => 42 })
    end

    it 'returns empty hash for nil/empty' do
      expect(described_class.parse_tool_calls(nil)).to eq({})
      expect(described_class.parse_tool_calls([])).to eq({})
    end
  end

  describe '.format_tool_call' do
    it 'skips when tool_calls are empty and logs' do
      msg = RubyLLM::Message.new(role: :assistant, content: '', tool_calls: {})
      allow(RubyLLM.logger).to receive(:warn)
      expect(tools.format_tool_call(msg, role: 'assistant')).to be_nil
      expect(RubyLLM.logger).to have_received(:warn).with(/tool_calls empty/)
    end

    it 'filters out calls with missing id and warns if all removed' do
      calls = {
        a: RubyLLM::ToolCall.new(id: '', name: 'x', arguments: {}),
        b: RubyLLM::ToolCall.new(id: nil, name: 'y', arguments: {})
      }
      msg = RubyLLM::Message.new(role: :assistant, content: '', tool_calls: calls)
      allow(RubyLLM.logger).to receive(:warn)
      expect(tools.format_tool_call(msg, role: 'assistant')).to be_nil
      expect(RubyLLM.logger).to have_received(:warn).with(/missing ids/)
    end

    it 'builds toolUse content blocks' do
      calls = {
        a: RubyLLM::ToolCall.new(id: 'id1', name: 'search', arguments: { q: 'ruby' }),
        b: RubyLLM::ToolCall.new(id: 'id2', name: 'calc', arguments: { x: 1 })
      }
      msg = RubyLLM::Message.new(role: :assistant, content: '', tool_calls: calls)
      result = tools.format_tool_call(msg, role: 'assistant')
      expect(result[:role]).to eq('assistant')
      expect(result[:content]).to contain_exactly(
        { 'toolUse' => { 'toolUseId' => 'id1', 'name' => 'search', 'input' => { q: 'ruby' } } },
        { 'toolUse' => { 'toolUseId' => 'id2', 'name' => 'calc', 'input' => { x: 1 } } }
      )
    end
  end

  describe '.format_tool_result' do
    it 'skips when tool_call_id missing' do
      msg = RubyLLM::Message.new(role: :tool, content: 'ok', tool_call_id: '')
      allow(RubyLLM.logger).to receive(:warn)
      expect(tools.format_tool_result(msg, role: 'user')).to be_nil
      expect(RubyLLM.logger).to have_received(:warn).with(/tool_call_id is null or empty/)
    end

    it 'formats tool result content' do
      msg = RubyLLM::Message.new(role: :tool, content: 'ok', tool_call_id: 'tu_1')
      result = tools.format_tool_result(msg, role: 'user')
      expect(result[:role]).to eq('user')
      expect(result[:content]).to eq([
                                       { 'toolResult' => { 'toolUseId' => 'tu_1', 'content' => [{ 'text' => 'ok' }] } }
                                     ])
    end
  end

  describe '.tool_result_only_message?' do
    it 'returns true when all content blocks are toolResult' do
      message = {
        role: 'assistant',
        content: [
          { 'toolResult' => { 'toolUseId' => 'a', 'content' => [{ 'text' => '1' }] } },
          { 'toolResult' => { 'toolUseId' => 'b', 'content' => [{ 'text' => '2' }] } }
        ]
      }

      expect(tools.tool_result_only_message?(message)).to be(true)
    end

    it 'returns false when any content block is not toolResult' do
      message = { role: 'assistant', content: [{ 'text' => 'Hello' }] }
      expect(tools.tool_result_only_message?(message)).to be(false)
    end
  end

  describe '.validate_no_tool_use_and_result!' do
    it 'raises when a message contains both toolUse and toolResult' do
      msg = { role: 'assistant', content: [{ 'toolUse' => {} }, { 'toolResult' => {} }] }
      expect do
        tools.validate_no_tool_use_and_result!([msg])
      end.to raise_error(/Message cannot contain both/)
    end
  end
end
