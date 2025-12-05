# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::SchemaValidator do
  describe '#validate!' do
    subject(:validate!) { described_class.new(schema).validate! }

    context 'with valid schemas' do
      let(:schema) { { type: 'object', properties: { name: { type: 'string' } }, additionalProperties: false } }

      it 'accepts schema with additionalProperties: false' do
        expect { validate! }.not_to raise_error
      end
    end

    context 'with string keys' do
      let(:schema) do
        {
          'type' => 'object',
          'properties' => { 'name' => { 'type' => 'string' } },
          'additionalProperties' => false
        }
      end

      it 'accepts schema with string keys' do
        expect { validate! }.not_to raise_error
      end
    end

    context 'with missing additionalProperties' do
      let(:schema) { { type: 'object', properties: { name: { type: 'string' } } } }

      it 'rejects schema' do
        expect { validate! }.to raise_error(ArgumentError, /additionalProperties.*to false/)
      end
    end

    context 'with nested object missing additionalProperties' do
      let(:schema) do
        {
          type: 'object',
          properties: { user: { type: 'object', properties: { name: { type: 'string' } } } },
          additionalProperties: false
        }
      end

      it 'rejects schema and reports path' do
        expect { validate! }.to raise_error(ArgumentError, /schema\.properties\.user/)
      end
    end

    context 'with array items containing objects' do
      let(:schema) do
        {
          type: 'object',
          properties: {
            users: {
              type: 'array',
              items: { type: 'object', properties: { name: { type: 'string' } } }
            }
          },
          additionalProperties: false
        }
      end

      it 'rejects invalid nested array items' do
        expect { validate! }.to raise_error(ArgumentError, /schema\.properties\.users\.items/)
      end
    end

    context 'with valid array items' do
      let(:schema) do
        {
          type: 'object',
          properties: {
            users: {
              type: 'array',
              items: { type: 'object', properties: { name: { type: 'string' } }, additionalProperties: false }
            }
          },
          additionalProperties: false
        }
      end

      it 'accepts valid nested array items' do
        expect { validate! }.not_to raise_error
      end
    end

    context 'with anyOf containing invalid object' do
      let(:schema) do
        {
          type: 'object',
          properties: {
            value: {
              anyOf: [
                { type: 'string' },
                { type: 'object', properties: { id: { type: 'integer' } } }
              ]
            }
          },
          additionalProperties: false
        }
      end

      it 'rejects invalid object in anyOf' do
        expect { validate! }.to raise_error(ArgumentError, /schema\.properties\.value\.anyOf\[1\]/)
      end
    end

    context 'with non-object types' do
      let(:schema) { { type: 'string' } }

      it 'accepts non-object schemas without additionalProperties' do
        expect { validate! }.not_to raise_error
      end
    end
  end
end
