# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::StructuredOutput::Schema do
  describe 'schema definition' do
    subject { schema.json_schema }

    let(:schema_class) do
      Class.new(described_class) do
        string :name, description: "User's name"
        number :age
        boolean :active

        object :address do
          string :street
          string :city
        end

        array :tags, :string, description: 'User tags'

        array :contacts do
          object do
            string :email
            string :phone
          end
        end

        any_of :status do
          string enum: %w[active pending]
          null
        end

        define :location do
          string :latitude
          string :longitude
        end

        array :locations, :location
      end
    end

    let(:schema) { schema_class.new }

    it 'generates the correct JSON schema' do
      expect(subject).to include(
        name: schema_class.name,
        description: 'Schema for the structured response'
      )

      properties = subject[:schema][:properties]

      # Test basic types
      expect(properties[:name]).to eq({ type: 'string', description: "User's name" })
      expect(properties[:age]).to eq({ type: 'number' })
      expect(properties[:active]).to eq({ type: 'boolean' })

      # Test nested object
      expect(properties[:address]).to include(
        type: 'object',
        properties: {
          street: { type: 'string' },
          city: { type: 'string' }
        },
        required: %i[street city],
        additionalProperties: false
      )

      # Test arrays
      expect(properties[:tags]).to eq({
                                        type: 'array',
                                        description: 'User tags',
                                        items: { type: 'string' }
                                      })

      expect(properties[:contacts]).to include(
        type: 'array',
        items: {
          type: 'object',
          properties: {
            email: { type: 'string' },
            phone: { type: 'string' }
          },
          required: %i[email phone],
          additionalProperties: false
        }
      )

      # Test any_of
      expect(properties[:status]).to include(
        anyOf: [
          { type: 'string', enum: %w[active pending] },
          { type: 'null' }
        ]
      )

      # Test references
      expect(properties[:locations]).to eq({
                                             type: 'array',
                                             items: { '$ref' => '#/$defs/location' }
                                           })

      # Test definitions
      expect(subject[:schema]['$defs']).to include(
        location: {
          type: 'object',
          properties: {
            latitude: { type: 'string' },
            longitude: { type: 'string' }
          },
          required: %i[latitude longitude]
        }
      )
    end

    it 'includes all properties in required array' do
      expect(subject[:schema][:required]).to contain_exactly(
        :name, :age, :active, :address, :tags, :contacts, :status, :locations
      )
    end

    it 'enforces schema constraints' do
      expect(subject[:schema]).to include(
        additionalProperties: false,
        strict: true
      )
    end
  end
end
