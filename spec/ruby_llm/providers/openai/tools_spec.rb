# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/tool'

RSpec.describe RubyLLM::Providers::OpenAI::Tools do # rubocop:disable RSpec/SpecFilePathFormat
  describe '.param_schema' do
    context 'with array type parameter' do
      it 'includes items field for array parameters with default string type' do
        param = RubyLLM::Parameter.new('tags', type: 'array', desc: 'List of tags')

        result = described_class.param_schema(param)

        expect(result).to eq(
          type: 'array',
          description: 'List of tags',
          items: { type: 'string' }
        )
      end

      it 'supports arrays of integers' do
        param = RubyLLM::Parameter.new('scores', type: 'array', desc: 'List of scores', item_type: 'integer')

        result = described_class.param_schema(param)

        expect(result).to eq(
          type: 'array',
          description: 'List of scores',
          items: { type: 'integer' }
        )
      end

      it 'supports arrays of numbers' do
        param = RubyLLM::Parameter.new('prices', type: 'array', desc: 'List of prices', item_type: 'number')

        result = described_class.param_schema(param)

        expect(result).to eq(
          type: 'array',
          description: 'List of prices',
          items: { type: 'number' }
        )
      end

      it 'supports arrays of booleans' do
        param = RubyLLM::Parameter.new('flags', type: 'array', desc: 'List of flags', item_type: 'boolean')

        result = described_class.param_schema(param)

        expect(result).to eq(
          type: 'array',
          description: 'List of flags',
          items: { type: 'boolean' }
        )
      end

      it 'supports arrays of objects' do
        param = RubyLLM::Parameter.new('users', type: 'array', desc: 'List of users', item_type: 'object')

        result = described_class.param_schema(param)

        expect(result).to eq(
          type: 'array',
          description: 'List of users',
          items: { type: 'object' }
        )
      end
    end

    context 'with non-array parameters' do
      it 'does not include items field for string parameters' do
        param = RubyLLM::Parameter.new('name', type: 'string', desc: 'Name field')

        result = described_class.param_schema(param)

        expect(result).to eq(
          type: 'string',
          description: 'Name field'
        )
      end

      it 'does not include items field for integer parameters' do
        param = RubyLLM::Parameter.new('age', type: 'integer', desc: 'Age field')

        result = described_class.param_schema(param)

        expect(result).to eq(
          type: 'integer',
          description: 'Age field'
        )
      end

      it 'does not include items field for boolean parameters' do
        param = RubyLLM::Parameter.new('active', type: 'boolean', desc: 'Active status')

        result = described_class.param_schema(param)

        expect(result).to eq(
          type: 'boolean',
          description: 'Active status'
        )
      end

      it 'does not include items field for object parameters' do
        param = RubyLLM::Parameter.new('metadata', type: 'object', desc: 'Metadata')

        result = described_class.param_schema(param)

        expect(result).to eq(
          type: 'object',
          description: 'Metadata'
        )
      end
    end
  end

  describe '.tool_for' do
    it 'formats tools with array parameters correctly for OpenAI API' do
      tool_class = Class.new(RubyLLM::Tool) do
        def self.name
          'DataProcessor'
        end

        description 'Process data with specific fields'
        param :fields, type: 'array', desc: 'Fields to process', required: true
        param :format, type: 'string', desc: 'Output format', required: false
        param :limit, type: 'integer', desc: 'Limit results', required: false

        def execute(fields:, format: 'json', limit: 10)
          "Processed #{fields.length} fields in #{format} format (limit: #{limit})"
        end
      end

      tool = tool_class.new
      result = described_class.tool_for(tool)

      expect(result[:type]).to eq('function')
      expect(result[:function][:name]).to eq('data_processor')
      expect(result[:function][:description]).to eq('Process data with specific fields')

      # Verify array parameter has items field
      expect(result[:function][:parameters][:properties][:fields]).to eq(
        type: 'array',
        description: 'Fields to process',
        items: { type: 'string' }
      )

      # Verify string parameter doesn't have items field
      expect(result[:function][:parameters][:properties][:format]).to eq(
        type: 'string',
        description: 'Output format'
      )

      # Verify integer parameter doesn't have items field
      expect(result[:function][:parameters][:properties][:limit]).to eq(
        type: 'integer',
        description: 'Limit results'
      )

      # Verify only required parameters are marked as required
      expect(result[:function][:parameters][:required]).to contain_exactly(:fields)
    end

    it 'handles tools with multiple array parameters' do
      tool_class = Class.new(RubyLLM::Tool) do
        def self.name
          'MultiArrayTool'
        end

        description 'Tool with multiple array parameters'
        param :tags, type: 'array', desc: 'Tags list', required: true
        param :categories, type: 'array', desc: 'Categories list', required: false

        def execute(tags:, categories: [])
          { tags: tags, categories: categories }
        end
      end

      tool = tool_class.new
      result = described_class.tool_for(tool)

      # Both array parameters should have items field
      expect(result[:function][:parameters][:properties][:tags]).to eq(
        type: 'array',
        description: 'Tags list',
        items: { type: 'string' }
      )

      expect(result[:function][:parameters][:properties][:categories]).to eq(
        type: 'array',
        description: 'Categories list',
        items: { type: 'string' }
      )

      expect(result[:function][:parameters][:required]).to contain_exactly(:tags)
    end
  end
end
