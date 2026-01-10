# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::Tool do
  describe '#initialize' do
    it 'stores name, description, and schema' do
      tool = described_class.new(
        name: 'calculator',
        description: 'Does math',
        input_schema: { expression: { type: :string } }
      )
      expect(tool.name).to eq('calculator')
      expect(tool.description).to eq('Does math')
      expect(tool.input_schema).to eq({ expression: { type: :string } })
    end

    it 'accepts symbol name' do
      tool = described_class.new(name: :test, description: 'Test')
      expect(tool.name).to eq('test')
    end
  end

  describe '#call' do
    it 'executes the handler with input' do
      tool = described_class.new(
        name: 'adder',
        description: 'Adds numbers',
        input_schema: {
          type: :object,
          properties: { a: { type: :number }, b: { type: :number } },
          required: %i[a b]
        }
      ) do |input|
        input[:a] + input[:b]
      end

      result = tool.call(a: 2, b: 3)
      expect(result).to eq(5)
    end

    it 'raises NotImplementedError when no handler' do
      tool = described_class.new(name: 'empty', description: 'No handler')
      expect { tool.call({}) }.to raise_error(NotImplementedError, /No handler/)
    end

    it 'validates required fields' do
      tool = described_class.new(
        name: 'test',
        description: 'Test',
        input_schema: { required: [:name] }
      ) { |_| 'ok' }

      expect { tool.call({}) }.to raise_error(ArgumentError, /Missing required field: name/)
    end

    it 'symbolizes input keys' do
      received_input = nil
      tool = described_class.new(name: 'test', description: 'Test') do |input|
        received_input = input
        'ok'
      end

      tool.call('string_key' => 'value')
      expect(received_input).to have_key(:string_key)
    end
  end

  describe '#execute' do
    it 'is an alias for #call' do
      tool = described_class.new(name: 'test', description: 'Test') { 'executed' }
      expect(tool.execute({})).to eq('executed')
    end
  end

  describe '#to_h' do
    it 'returns hash representation' do
      tool = described_class.new(
        name: 'test',
        description: 'A test tool',
        input_schema: { foo: :bar }
      )
      expect(tool.to_h).to eq({
        name: 'test',
        description: 'A test tool',
        input_schema: { foo: :bar }
      })
    end
  end

  describe '#to_json_schema' do
    it 'returns OpenAI-compatible function schema' do
      tool = described_class.new(
        name: 'weather',
        description: 'Get weather',
        input_schema: {
          type: :object,
          properties: { location: { type: :string } }
        }
      )

      schema = tool.to_json_schema
      expect(schema[:type]).to eq('function')
      expect(schema[:function][:name]).to eq('weather')
      expect(schema[:function][:description]).to eq('Get weather')
      expect(schema[:function][:parameters]).to eq({
        type: :object,
        properties: { location: { type: :string } }
      })
    end
  end

  describe '.from_h' do
    it 'creates tool from hash' do
      tool = described_class.from_h({
        name: 'from_hash',
        description: 'Created from hash',
        input_schema: {}
      }) { 'handler' }

      expect(tool.name).to eq('from_hash')
      expect(tool.description).to eq('Created from hash')
      expect(tool.call({})).to eq('handler')
    end

    it 'handles string keys' do
      tool = described_class.from_h({
        'name' => 'string_keys',
        'description' => 'String keys'
      })
      expect(tool.name).to eq('string_keys')
    end
  end
end

RSpec.describe RubyLLM::AgentSDK::ToolRegistry do
  let(:registry) { described_class.new }

  let(:tool1) do
    RubyLLM::AgentSDK::Tool.new(name: 'tool1', description: 'First') { 'result1' }
  end

  let(:tool2) do
    RubyLLM::AgentSDK::Tool.new(name: 'tool2', description: 'Second') { 'result2' }
  end

  describe '#register' do
    it 'adds tool to registry' do
      registry.register(tool1)
      expect(registry['tool1']).to eq(tool1)
    end

    it 'supports << operator' do
      registry << tool1
      expect(registry.include?('tool1')).to be true
    end
  end

  describe '#[]' do
    it 'retrieves tool by name' do
      registry.register(tool1)
      expect(registry['tool1']).to eq(tool1)
    end

    it 'accepts symbol' do
      registry.register(tool1)
      expect(registry[:tool1]).to eq(tool1)
    end

    it 'returns nil for unknown tool' do
      expect(registry['unknown']).to be_nil
    end
  end

  describe '#include?' do
    it 'returns true for registered tools' do
      registry.register(tool1)
      expect(registry.include?('tool1')).to be true
      expect(registry.include?(:tool1)).to be true
    end

    it 'returns false for unknown tools' do
      expect(registry.include?('unknown')).to be false
    end
  end

  describe '#call' do
    it 'executes tool by name' do
      registry.register(tool1)
      result = registry.call('tool1')
      expect(result).to eq('result1')
    end

    it 'raises for unknown tool' do
      expect { registry.call('unknown') }.to raise_error(ArgumentError, /Unknown tool/)
    end
  end

  describe '#each' do
    it 'iterates over all tools' do
      registry.register(tool1)
      registry.register(tool2)

      names = []
      registry.each { |t| names << t.name }
      expect(names).to contain_exactly('tool1', 'tool2')
    end
  end

  describe '#names' do
    it 'returns all tool names' do
      registry.register(tool1)
      registry.register(tool2)
      expect(registry.names).to contain_exactly('tool1', 'tool2')
    end
  end

  describe '#size' do
    it 'returns count of tools' do
      expect(registry.size).to eq(0)
      registry.register(tool1)
      expect(registry.size).to eq(1)
    end
  end

  describe '#to_json_schema' do
    it 'returns array of JSON schemas' do
      registry.register(tool1)
      registry.register(tool2)

      schemas = registry.to_json_schema
      expect(schemas.size).to eq(2)
      expect(schemas.first[:type]).to eq('function')
    end
  end
end
