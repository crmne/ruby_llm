# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Tools do
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
end
