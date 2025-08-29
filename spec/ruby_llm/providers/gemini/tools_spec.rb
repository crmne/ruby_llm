# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/tool'

RSpec.describe RubyLLM::Providers::Gemini::Tools do
  let(:dummy_class) do
    Class.new do
      include RubyLLM::Providers::Gemini::Tools
    end
  end

  let(:instance) { dummy_class.new }

  describe '#format_parameters' do
    context 'with array type parameter' do
      it 'includes items field for array parameters' do
        parameters = {
          fields: RubyLLM::Parameter.new('fields', type: 'array', desc: 'List of fields to return')
        }

        result = instance.send(:format_parameters, parameters)

        expect(result[:type]).to eq('OBJECT')
        expect(result[:properties][:fields]).to eq(
          type: 'ARRAY',
          description: 'List of fields to return',
          items: { type: 'STRING' }
        )
      end
    end

    context 'with mixed parameter types' do
      it 'correctly formats all parameter types including arrays with items field' do
        parameters = {
          name: RubyLLM::Parameter.new('name', type: 'string', desc: 'Name field'),
          count: RubyLLM::Parameter.new('count', type: 'integer', desc: 'Count field'),
          active: RubyLLM::Parameter.new('active', type: 'boolean', desc: 'Active status'),
          tags: RubyLLM::Parameter.new('tags', type: 'array', desc: 'List of tags'),
          metadata: RubyLLM::Parameter.new('metadata', type: 'object', desc: 'Additional metadata')
        }

        result = instance.send(:format_parameters, parameters)

        expect(result[:type]).to eq('OBJECT')

        # String parameter - no items field
        expect(result[:properties][:name]).to eq(
          type: 'STRING',
          description: 'Name field'
        )

        # Integer parameter - no items field
        expect(result[:properties][:count]).to eq(
          type: 'NUMBER',
          description: 'Count field'
        )

        # Boolean parameter - no items field
        expect(result[:properties][:active]).to eq(
          type: 'BOOLEAN',
          description: 'Active status'
        )

        # Array parameter - MUST have items field
        expect(result[:properties][:tags]).to eq(
          type: 'ARRAY',
          description: 'List of tags',
          items: { type: 'STRING' }
        )

        # Object parameter - no items field
        expect(result[:properties][:metadata]).to eq(
          type: 'OBJECT',
          description: 'Additional metadata'
        )
      end
    end

    context 'with required and optional parameters' do
      it 'correctly identifies required parameters' do
        parameters = {
          required_field: RubyLLM::Parameter.new('required_field', type: 'string', desc: 'Required', required: true),
          optional_field: RubyLLM::Parameter.new('optional_field', type: 'string', desc: 'Optional', required: false),
          required_array: RubyLLM::Parameter.new('required_array', type: 'array', desc: 'Required array',
                                                                   required: true)
        }

        result = instance.send(:format_parameters, parameters)

        expect(result[:required]).to contain_exactly('required_field', 'required_array')

        # Also verify array parameter has items field
        expect(result[:properties][:required_array]).to include(
          type: 'ARRAY',
          items: { type: 'STRING' }
        )
      end
    end
  end

  describe '#format_tools' do
    it 'formats tools with array parameters correctly for Gemini API' do
      tool_class = Class.new(RubyLLM::Tool) do
        def self.name
          'DataProcessor'
        end

        description 'Process data with specific fields'
        param :fields, type: 'array', desc: 'Fields to process', required: true
        param :format, type: 'string', desc: 'Output format', required: false

        def execute(fields:, format: 'json')
          "Processed #{fields.length} fields in #{format} format"
        end
      end

      tools = { data_processor: tool_class.new }
      result = instance.send(:format_tools, tools)

      expect(result).to be_an(Array)
      expect(result.first[:functionDeclarations]).to be_an(Array)

      function_decl = result.first[:functionDeclarations].first
      expect(function_decl[:name]).to eq('data_processor')
      expect(function_decl[:description]).to eq('Process data with specific fields')

      # Verify array parameter has items field (this is the critical fix)
      expect(function_decl[:parameters][:properties][:fields]).to eq(
        type: 'ARRAY',
        description: 'Fields to process',
        items: { type: 'STRING' }
      )

      # Verify string parameter doesn't have items field
      expect(function_decl[:parameters][:properties][:format]).to eq(
        type: 'STRING',
        description: 'Output format'
      )

      # Verify only required parameters are marked as required
      expect(function_decl[:parameters][:required]).to contain_exactly('fields')
    end
  end
end
