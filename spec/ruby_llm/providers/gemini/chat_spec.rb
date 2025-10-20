# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Gemini::Chat do
  include_context 'with configured RubyLLM'

  # Create a test object that includes the module to access private methods
  let(:test_obj) do
    Object.new.tap do |obj|
      obj.extend(described_class)
    end
  end

  describe '#convert_schema_to_gemini' do
    it 'converts simple string schema' do
      schema = { type: 'string' }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'STRING' })
    end

    it 'converts string schema with enum' do
      schema = { type: 'string', enum: %w[red green blue] }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'STRING', enum: %w[red green blue] })
    end

    it 'converts string schema with format' do
      schema = { type: 'string', format: 'email' }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'STRING', format: 'email' })
    end

    it 'converts number schema' do
      schema = { type: 'number' }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'NUMBER' })
    end

    it 'converts number schema with constraints' do
      schema = {
        type: 'number',
        minimum: 0,
        maximum: 100,
        format: 'float'
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'NUMBER',
                             format: 'float',
                             minimum: 0,
                             maximum: 100
                           })
    end

    it 'converts integer schema' do
      schema = { type: 'integer' }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'INTEGER' })
    end

    it 'converts boolean schema' do
      schema = { type: 'boolean' }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'BOOLEAN' })
    end

    it 'converts array schema' do
      schema = {
        type: 'array',
        items: { type: 'string' }
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'ARRAY',
                             items: { type: 'STRING' }
                           })
    end

    it 'converts array schema with constraints' do
      schema = {
        type: 'array',
        items: { type: 'integer' },
        minItems: 1,
        maxItems: 10
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'ARRAY',
                             items: { type: 'INTEGER' },
                             minItems: 1,
                             maxItems: 10
                           })
    end

    it 'converts array schema without items to default STRING' do
      schema = { type: 'array' }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'ARRAY',
                             items: { type: 'STRING' }
                           })
    end

    it 'converts object schema' do
      schema = {
        type: 'object',
        properties: {
          name: { type: 'string' },
          age: { type: 'integer' }
        },
        required: %w[name]
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'OBJECT',
                             properties: {
                               name: { type: 'STRING' },
                               age: { type: 'INTEGER' }
                             },
                             required: %w[name]
                           })
    end

    it 'converts object schema with propertyOrdering' do
      schema = {
        type: 'object',
        properties: {
          name: { type: 'string' },
          age: { type: 'integer' }
        },
        propertyOrdering: %w[name age]
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to include(propertyOrdering: %w[name age])
    end

    it 'handles nullable fields' do
      schema = {
        type: 'string',
        nullable: true
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'STRING',
                             nullable: true
                           })
    end

    it 'handles descriptions' do
      schema = {
        type: 'string',
        description: 'A user name'
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'STRING',
                             description: 'A user name'
                           })
    end

    it 'converts nested object schemas' do
      schema = {
        type: 'object',
        properties: {
          user: {
            type: 'object',
            properties: {
              name: { type: 'string' },
              contacts: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    type: { type: 'string', enum: %w[email phone] },
                    value: { type: 'string' }
                  }
                }
              }
            }
          }
        }
      }

      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result[:type]).to eq('OBJECT')
      expect(result[:properties][:user][:type]).to eq('OBJECT')
      expect(result[:properties][:user][:properties][:name][:type]).to eq('STRING')
      expect(result[:properties][:user][:properties][:contacts][:type]).to eq('ARRAY')
      expect(result[:properties][:user][:properties][:contacts][:items][:type]).to eq('OBJECT')
      expect(result[:properties][:user][:properties][:contacts][:items][:properties][:type][:enum]).to eq(%w[email
                                                                                                             phone])
    end

    it 'handles nil schema' do
      result = test_obj.send(:convert_schema_to_gemini, nil)
      expect(result).to be_nil
    end

    it 'defaults unknown types to STRING' do
      schema = { type: 'unknown' }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'STRING' })
    end

    it 'converts anyOf with null to nullable' do
      schema = {
        anyOf: [
          { type: 'string', format: 'email' },
          { type: 'null' }
        ]
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'STRING',
                             format: 'email',
                             nullable: true
                           })
    end

    it 'converts anyOf with multiple non-null types by choosing first' do
      schema = {
        anyOf: [
          { type: 'string' },
          { type: 'integer' }
        ]
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'STRING' })
    end

    it 'converts anyOf with only null to nullable string' do
      schema = {
        anyOf: [
          { type: 'null' }
        ]
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'STRING',
                             nullable: true
                           })
    end

    it 'converts complex schema with anyOf in properties' do
      schema = {
        type: 'object',
        properties: {
          email: {
            anyOf: [
              { type: 'string', format: 'email' },
              { type: 'null' }
            ]
          },
          name: { type: 'string' }
        },
        required: %w[name]
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result[:type]).to eq('OBJECT')
      expect(result[:properties][:email]).to eq({
                                                  type: 'STRING',
                                                  format: 'email',
                                                  nullable: true
                                                })
      expect(result[:properties][:name]).to eq({ type: 'STRING' })
    end
  end

  it 'correctly sums candidatesTokenCount and thoughtsTokenCount' do
    chat = RubyLLM.chat(model: 'gemini-2.5-flash', provider: :gemini)
    response = chat.ask('What is 2+2? Think step by step.')

    # Get the raw response to verify the token counting
    raw_body = response.raw.body

    candidates_tokens = raw_body.dig('usageMetadata', 'candidatesTokenCount') || 0
    thoughts_tokens = raw_body.dig('usageMetadata', 'thoughtsTokenCount') || 0

    # Verify our implementation correctly sums both token types
    expect(response.output_tokens).to eq(candidates_tokens + thoughts_tokens)
  end
end
