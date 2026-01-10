# frozen_string_literal: true

require 'ostruct'

RSpec.describe RubyLLM::AgentSDK::Tool do
  describe '#initialize' do
    it 'accepts name, description, and handler' do
      tool = described_class.new(
        name: 'my_tool',
        description: 'Does something useful'
      ) { |args| args[:input] }

      expect(tool.name).to eq('my_tool')
      expect(tool.description).to eq('Does something useful')
      expect(tool.handler).to be_a(Proc)
    end

    it 'converts name to string' do
      tool = described_class.new(name: :symbol_name, description: 'Test') {}
      expect(tool.name).to eq('symbol_name')
    end

    it 'normalizes shorthand schema to full JSON Schema' do
      tool = described_class.new(
        name: 'test',
        description: 'Test',
        input_schema: {
          query: { type: 'string', description: 'Search query' }
        }
      ) {}

      expect(tool.input_schema).to eq(
        type: 'object',
        properties: { query: { type: 'string', description: 'Search query' } },
        required: ['query']
      )
    end

    it 'preserves full JSON Schema format' do
      full_schema = {
        type: 'object',
        properties: {
          name: { type: 'string' }
        },
        required: ['name']
      }

      tool = described_class.new(
        name: 'test',
        description: 'Test',
        input_schema: full_schema
      ) {}

      expect(tool.input_schema).to eq(full_schema)
    end

    it 'defaults to empty schema' do
      tool = described_class.new(name: 'test', description: 'Test') {}
      expect(tool.input_schema).to eq(type: 'object', properties: {}, required: [])
    end
  end

  describe '#call' do
    it 'invokes the handler with input' do
      tool = described_class.new(
        name: 'echo',
        description: 'Echo input'
      ) { |args| "You said: #{args[:message]}" }

      result = tool.call(message: 'hello')
      expect(result).to eq('You said: hello')
    end

    it 'can return complex data' do
      tool = described_class.new(
        name: 'get_data',
        description: 'Get data'
      ) { |_| { status: 'ok', items: [1, 2, 3] } }

      result = tool.call({})
      expect(result).to eq(status: 'ok', items: [1, 2, 3])
    end
  end

  describe '#to_mcp_schema' do
    it 'returns MCP-compatible schema' do
      tool = described_class.new(
        name: 'search',
        description: 'Search for items',
        input_schema: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Search query' },
            limit: { type: 'integer', description: 'Max results' }
          },
          required: ['query']
        }
      ) {}

      schema = tool.to_mcp_schema

      expect(schema[:name]).to eq('search')
      expect(schema[:description]).to eq('Search for items')
      expect(schema[:inputSchema]).to eq(tool.input_schema)
    end
  end

  describe '.from_ruby_llm_tool' do
    let(:mock_tool_class) do
      Class.new do
        def self.description
          'Mock tool description'
        end

        def self.parameters
          {
            location: OpenStruct.new(type: :string, description: 'City name', required: true),
            units: OpenStruct.new(type: :string, description: 'Temperature units', required: false)
          }
        end

        def name
          'get_weather'
        end

        def call(location:, units: 'celsius')
          "Weather in #{location}: 20°#{units == 'celsius' ? 'C' : 'F'}"
        end
      end
    end

    it 'creates Tool from RubyLLM::Tool-like class' do
      tool = described_class.from_ruby_llm_tool(mock_tool_class)

      expect(tool.name).to eq('get_weather')
      expect(tool.description).to eq('Mock tool description')
    end

    it 'converts parameters to JSON Schema' do
      tool = described_class.from_ruby_llm_tool(mock_tool_class)

      expect(tool.input_schema[:type]).to eq('object')
      expect(tool.input_schema[:properties]['location']).to eq(
        type: 'string',
        description: 'City name'
      )
      expect(tool.input_schema[:required]).to include('location')
      expect(tool.input_schema[:required]).not_to include('units')
    end

    it 'creates callable handler' do
      tool = described_class.from_ruby_llm_tool(mock_tool_class)
      result = tool.call(location: 'Tokyo')

      expect(result).to eq('Weather in Tokyo: 20°C')
    end
  end

  describe '.ruby_type_to_json' do
    it 'converts Ruby types to JSON Schema types' do
      conversions = {
        'string' => 'string',
        'String' => 'string',
        'integer' => 'integer',
        'Integer' => 'integer',
        'int' => 'integer',
        'float' => 'number',
        'Float' => 'number',
        'number' => 'number',
        'boolean' => 'boolean',
        'Boolean' => 'boolean',
        'bool' => 'boolean',
        'array' => 'array',
        'Array' => 'array',
        'hash' => 'object',
        'Hash' => 'object',
        'object' => 'object',
        'unknown' => 'string'
      }

      conversions.each do |ruby_type, json_type|
        expect(described_class.ruby_type_to_json(ruby_type)).to eq(json_type),
          "Expected #{ruby_type} to convert to #{json_type}"
      end
    end
  end

  describe '.convert_parameters' do
    it 'returns empty hash for nil parameters' do
      expect(described_class.convert_parameters(nil)).to eq({})
    end

    it 'converts parameter hash to JSON Schema' do
      params = {
        name: OpenStruct.new(type: :string, description: 'User name', required: true),
        age: OpenStruct.new(type: :integer, description: 'User age', required: false)
      }

      schema = described_class.convert_parameters(params)

      expect(schema[:type]).to eq('object')
      expect(schema[:properties]['name']).to eq(type: 'string', description: 'User name')
      expect(schema[:properties]['age']).to eq(type: 'integer', description: 'User age')
      expect(schema[:required]).to eq(['name'])
    end
  end
end
