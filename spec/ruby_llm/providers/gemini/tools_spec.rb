# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Gemini::Tools do
  let(:tools_mod) { Class.new.extend(described_class) }

  describe '#function_declaration_for' do
    let(:complex_schema) do
      {
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
        strict: true,
        '$defs': {}
      }
    end

    it 'passes through a complex JSON Schema when tool.schema is present' do
      complex_schema = {
        type: 'object',
        properties: {
          node: {
            type: 'object',
            properties: {
              id: { type: 'string' },
              children: {
                type: 'array',
                items: { type: 'string' }
              }
            },
            required: %w[id]
          }
        },
        required: %w[node]
      }

      stub_const('GeminiSchemaTool', Class.new(RubyLLM::Tool) do
        description 'Gemini complex schema tool'
        schema complex_schema
        def execute(...); end
      end)

      tool = GeminiSchemaTool.new
      built = tools_mod.send(:function_declaration_for, tool)

      expect(built[:name]).to eq(tool.name)
      expect(built[:description]).to eq('Gemini complex schema tool')
      expect(built[:parameters]).to eq(complex_schema)
    end

    it 'accepts a RubyLLM::Schema class and matches the complex_schema JSON' do
      require 'ruby_llm/schema'

      class GeminiComplexSchema < RubyLLM::Schema
        array :items, required: true do
          object required: true do
            string :id, required: true
            object :meta, required: true do
              array :tags, of: :string, required: true
            end
          end
        end
      end

      dsl_schema = GeminiComplexSchema.new.to_json_schema[:schema]
      expect(dsl_schema.stringify_keys).to eq(complex_schema.stringify_keys)

      stub_const('GeminiSchemaBackedTool', Class.new(RubyLLM::Tool) do
        description 'Gemini tool using RubyLLM::Schema'
        schema GeminiComplexSchema
        def execute(...); end
      end)

      tool = GeminiSchemaBackedTool.new
      built = tools_mod.send(:function_declaration_for, tool)

      expect(built[:name]).to eq(tool.name)
      expect(built[:description]).to eq('Gemini tool using RubyLLM::Schema')
      expect(built[:parameters].stringify_keys).to eq(complex_schema.stringify_keys)
    end

    it 'builds a parameter-based schema when no schema is provided (with Gemini types)' do
      stub_const('GeminiParamOnlyTool', Class.new(RubyLLM::Tool) do
        description 'Gemini param-only tool'
        param :query, type: 'string', desc: 'The query', required: true
        param :limit, type: 'integer', desc: 'Max results', required: false
        param :flag, type: 'boolean', desc: 'A toggle', required: false
        def execute(...); end
      end)

      tool = GeminiParamOnlyTool.new
      built = tools_mod.send(:function_declaration_for, tool)

      expect(built[:name]).to eq(tool.name)
      expect(built[:description]).to eq('Gemini param-only tool')
      expect(built[:parameters]).to eq(
        type: 'OBJECT',
        properties: {
          query: { type: 'STRING', description: 'The query' },
          limit: { type: 'NUMBER', description: 'Max results' },
          flag: { type: 'BOOLEAN', description: 'A toggle' }
        },
        required: %w[query]
      )
    end

    it 'allows empty parameters when neither schema nor parameters are provided' do
      stub_const('GeminiEmptyTool', Class.new(RubyLLM::Tool) do
        description 'Gemini empty tool'
        def execute(...); end
      end)

      tool = GeminiEmptyTool.new
      built = tools_mod.send(:function_declaration_for, tool)

      expect(built[:name]).to eq(tool.name)
      expect(built[:description]).to eq('Gemini empty tool')
      expect(built[:parameters]).to eq({})
    end
  end
end
