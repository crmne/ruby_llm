# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Tools do
  let(:tools) { described_class }
  let(:complex_schema) do
    {
      '$defs': {},
      type: 'object',
      additionalProperties: false,
      properties: {
        items: {
          type: 'array',
          items: {
            type: 'object',
            additionalProperties: false,
            properties: {
              id: { type: 'string' },
              meta: {
                type: 'object',
                additionalProperties: false,
                properties: {
                  tags: { type: 'array', items: { type: 'string' } }
                },
                required: %i[tags]
              }
            },
            required: %i[id meta]
          }
        }
      },
      required: %i[items],
      strict: true
    }
  end

  describe '.tool_for' do
    it 'accepts a RubyLLM::Schema class and matches the complex_schema JSON' do
      require 'ruby_llm/schema'

      class OpenAIComplexSchema < RubyLLM::Schema
        array :items, required: true do
          object do
            string :id, required: true
            object :meta do
              array :tags, of: :string, required: true
            end
          end
        end
      end

      dsl_schema = OpenAIComplexSchema.new.to_json_schema[:schema]
      expect(dsl_schema.stringify_keys).to eq(complex_schema.stringify_keys)

      stub_const('OpenAISchemaBackedTool', Class.new(RubyLLM::Tool) do
        description 'OpenAI tool using RubyLLM::Schema'
        schema OpenAIComplexSchema
        def execute(...); end
      end)

      tool = OpenAISchemaBackedTool.new
      built = tools.tool_for(tool)

      expect(built[:type]).to eq('function')
      expect(built[:function][:name]).to eq(tool.name)
      expect(built[:function][:description]).to eq('OpenAI tool using RubyLLM::Schema')
      expect(built[:function][:parameters].stringify_keys).to eq(complex_schema.stringify_keys)
    end

    it 'passes through a complex JSON Schema when tool.schema is present' do
      tool_schema = complex_schema
      stub_const('ComplexSchemaTool', Class.new(RubyLLM::Tool) do
        description 'Complex schema tool'
        schema tool_schema

        def execute(...); end
      end)

      tool = ComplexSchemaTool.new
      built = tools.tool_for(tool)

      expect(built[:type]).to eq('function')
      expect(built[:function][:name]).to eq(tool.name)
      expect(built[:function][:description]).to eq(tool.description)
      expect(built[:function][:parameters]).to eq(complex_schema)
    end

    it 'builds a parameter-based schema when no schema is provided' do
      stub_const('ParamOnlyTool', Class.new(RubyLLM::Tool) do
        description 'Param-only tool'
        param :query, type: 'string', desc: 'The query', required: true
        param :limit, type: 'integer', desc: 'Max results', required: false

        def execute(...); end
      end)

      tool = ParamOnlyTool.new
      built = tools.tool_for(tool)

      expect(built[:type]).to eq('function')
      fn = built[:function]
      expect(fn[:name]).to eq(tool.name)
      expect(fn[:description]).to eq('Param-only tool')
      expect(fn[:parameters]).to eq(
        type: 'object',
        properties: {
          query: { type: 'string', description: 'The query' },
          limit: { type: 'integer', description: 'Max results' }
        },
        required: [:query]
      )
    end

    it 'allows empty parameters when neither schema nor parameters are provided' do
      stub_const('OpenAIEmptyTool', Class.new(RubyLLM::Tool) do
        description 'OpenAI empty tool'
        def execute(...); end
      end)

      tool = OpenAIEmptyTool.new
      built = tools.tool_for(tool)

      expect(built[:type]).to eq('function')
      expect(built[:function][:name]).to eq(tool.name)
      expect(built[:function][:description]).to eq('OpenAI empty tool')
      expect(built[:function][:parameters]).to eq(nil)
    end
  end
end
