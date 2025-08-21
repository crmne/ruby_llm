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
        expect(result[:properties][:fields]).to include(
          type: 'ARRAY',
          description: 'List of fields to return',
          items: { type: 'STRING' }
        )
      end
    end

    context 'with mixed parameter types' do
      it 'correctly formats all parameter types' do
        parameters = {
          name: RubyLLM::Parameter.new('name', type: 'string', desc: 'Name field'),
          age: RubyLLM::Parameter.new('age', type: 'integer', desc: 'Age field'),
          active: RubyLLM::Parameter.new('active', type: 'boolean', desc: 'Active status'),
          tags: RubyLLM::Parameter.new('tags', type: 'array', desc: 'List of tags'),
          metadata: RubyLLM::Parameter.new('metadata', type: 'object', desc: 'Additional metadata')
        }

        result = instance.send(:format_parameters, parameters)

        expect(result[:type]).to eq('OBJECT')

        # Check string parameter
        expect(result[:properties][:name]).to eq(
          type: 'STRING',
          description: 'Name field'
        )

        # Check integer parameter
        expect(result[:properties][:age]).to eq(
          type: 'NUMBER',
          description: 'Age field'
        )

        # Check boolean parameter
        expect(result[:properties][:active]).to eq(
          type: 'BOOLEAN',
          description: 'Active status'
        )

        # Check array parameter with items field
        expect(result[:properties][:tags]).to eq(
          type: 'ARRAY',
          description: 'List of tags',
          items: { type: 'STRING' }
        )

        # Check object parameter
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
          optional_field: RubyLLM::Parameter.new('optional_field', type: 'string', desc: 'Optional', required: false)
        }

        result = instance.send(:format_parameters, parameters)

        expect(result[:required]).to contain_exactly('required_field')
      end
    end
  end

  describe '#format_tools' do
    it 'formats tools with array parameters correctly' do
      tool_class = Class.new(RubyLLM::Tool) do
        def self.name
          'ProcessFieldsTool'
        end

        description 'Process multiple fields'
        param :fields, type: 'array', desc: 'Fields to process'

        def execute(fields:)
          "Processed #{fields.length} fields"
        end
      end

      tools = { process_fields: tool_class.new }
      result = instance.send(:format_tools, tools)

      expect(result).to be_an(Array)
      expect(result.first[:functionDeclarations]).to be_an(Array)

      function_decl = result.first[:functionDeclarations].first
      expect(function_decl[:name]).to eq('process_fields')
      expect(function_decl[:parameters][:properties][:fields]).to include(
        type: 'ARRAY',
        items: { type: 'STRING' }
      )
    end
  end
end
