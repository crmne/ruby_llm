# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::MCP::ParamHeaders do
  def tool(properties)
    { 'name' => 'query', 'inputSchema' => { 'type' => 'object', 'properties' => properties } }
  end

  def nested_tool(properties)
    tool('routing' => { 'type' => 'object', 'properties' => properties })
  end

  let(:region) { { 'type' => 'string', 'x-mcp-header' => 'Region' } }

  it 'mirrors marked arguments that have values' do
    definition = tool('region' => { 'type' => 'string', 'x-mcp-header' => 'Region' },
                      'verbose' => { 'type' => 'boolean', 'x-mcp-header' => 'Verbose' },
                      'limit' => { 'type' => 'integer', 'x-mcp-header' => 'Limit' },
                      'query' => { 'type' => 'string' })

    expect(described_class.for(definition, { region: 'us-west1', verbose: false, query: 'SELECT 1' }))
      .to eq('Region' => 'us-west1', 'Verbose' => 'false')
  end

  it 'rejects tools with invalid declarations' do
    expect(described_class.valid?(tool('a' => { 'type' => 'string', 'x-mcp-header' => 'Region' }))).to be(true)
    expect(described_class.valid?(tool('a' => { 'type' => 'number', 'x-mcp-header' => 'Price' }))).to be(false)
    expect(described_class.valid?(tool('a' => { 'type' => 'string', 'x-mcp-header' => 'Bad Name' }))).to be(false)
    expect(described_class.valid?(tool('a' => { 'type' => 'string', 'x-mcp-header' => 'Region' },
                                       'b' => { 'type' => 'string', 'x-mcp-header' => 'region' }))).to be(false)
  end

  describe 'nested properties' do
    it 'mirrors values from their exact property paths' do
      definition = nested_tool('region' => region)

      expect(described_class.for(definition, { region: 'wrong', routing: { region: 'us-west1' } }))
        .to eq('Region' => 'us-west1')
    end

    it 'mirrors several levels of properties alongside root arguments' do
      definition = tool(
        'region' => region,
        'routing' => { 'properties' => {
          'account' => { 'properties' => {
            'id' => { 'type' => 'string', 'x-mcp-header' => 'Account' }
          } }
        } }
      )

      expect(described_class.for(definition, { region: 'us-west1', routing: { account: { id: 'account-1' } } }))
        .to eq('Region' => 'us-west1', 'Account' => 'account-1')
    end

    it 'reads mixed String and Symbol argument keys' do
      definition = nested_tool('region' => region)

      expect(described_class.for(definition, { 'routing' => { region: 'us-west1' } })).to eq('Region' => 'us-west1')
      expect(described_class.for(definition, { routing: { 'region' => 'us-west1' } })).to eq('Region' => 'us-west1')
    end

    it 'keeps false and zero nested values' do
      definition = nested_tool(
        'verbose' => { 'type' => 'boolean', 'x-mcp-header' => 'Verbose' },
        'limit' => { 'type' => 'integer', 'x-mcp-header' => 'Limit' }
      )

      expect(described_class.for(definition, { routing: { verbose: false, limit: 0 } }))
        .to eq('Verbose' => 'false', 'Limit' => '0')
    end

    [{}, { routing: nil }, { routing: {} }, { routing: { region: nil } }].each do |arguments|
      it "omits a nested header when its path has no value in #{arguments.inspect}" do
        expect(described_class.for(nested_tool('region' => region), arguments)).to eq({})
      end
    end

    it 'keeps root headers when a nested object is absent' do
      definition = nested_tool('region' => region)
      definition['inputSchema']['properties']['limit'] = { 'type' => 'integer', 'x-mcp-header' => 'Limit' }

      expect(described_class.for(definition, { limit: 0 })).to eq('Limit' => '0')
    end

    it 'does not substitute defaults for missing arguments' do
      definition = nested_tool('region' => region.merge('default' => 'us-west1'))

      expect(described_class.for(definition, { routing: {} })).to eq({})
    end

    it 'preserves an empty nested string value' do
      expect(described_class.for(nested_tool('region' => region), { routing: { region: '' } }))
        .to eq('Region' => '')
    end

    it 'preserves safe integer boundary values' do
      definition = nested_tool('limit' => { 'type' => 'integer', 'x-mcp-header' => 'Limit' })
      maximum = (2**53) - 1

      [-maximum, maximum].each do |value|
        expect(described_class.for(definition, { routing: { limit: value } })).to eq('Limit' => value.to_s)
      end
    end

    it 'accepts valid nested declarations without changing the schema' do
      definition = nested_tool('region' => region)
      original = JSON.generate(definition)

      expect(described_class.valid?(definition)).to be(true)
      described_class.for(definition, { routing: { region: 'us-west1' } })
      expect(JSON.generate(definition)).to eq(original)
    end

    ['', nil, 42, 'Bad Name', "Region\r\nInjected"].each do |header|
      it "rejects a nested declaration with header #{header.inspect}" do
        definition = nested_tool('region' => region.merge('x-mcp-header' => header))

        expect(described_class.valid?(definition)).to be(false)
      end
    end

    %w[number object array].each do |type|
      it "rejects a nested declaration of type #{type}" do
        expect(described_class.valid?(nested_tool('region' => region.merge('type' => type)))).to be(false)
      end
    end

    it 'rejects case-insensitive header duplicates between root and nested properties' do
      definition = nested_tool('region' => region.merge('x-mcp-header' => 'region'))
      definition['inputSchema']['properties']['region'] = region

      expect(described_class.valid?(definition)).to be(false)
    end

    it 'rejects case-insensitive header duplicates in separate nested objects' do
      definition = nested_tool('region' => region)
      definition['inputSchema']['properties']['other'] = {
        'properties' => { 'region' => region.merge('x-mcp-header' => 'REGION') }
      }

      expect(described_class.valid?(definition)).to be(false)
    end
  end

  describe 'statically reachable declarations' do
    it 'rejects an annotation on the schema root' do
      definition = tool({})
      definition['inputSchema']['x-mcp-header'] = 'Root'

      expect(described_class.valid?(definition)).to be(false)
    end

    %w[items additionalItems contains additionalProperties unevaluatedItems unevaluatedProperties propertyNames
       not if then else contentSchema].each do |keyword|
      it "rejects an annotation under #{keyword}" do
        expect(described_class.valid?(tool('routing' => { keyword => region }))).to be(false)
      end
    end

    %w[allOf anyOf oneOf prefixItems].each do |keyword|
      it "rejects an annotation in the #{keyword} schema array" do
        expect(described_class.valid?(tool('routing' => { keyword => [region] }))).to be(false)
      end
    end

    %w[$defs definitions patternProperties dependentSchemas dependencies].each do |keyword|
      it "rejects an annotation under the #{keyword} schema map" do
        definition = tool({})
        definition['inputSchema'][keyword] = { 'entry' => region }

        expect(described_class.valid?(definition)).to be(false)
      end
    end

    it 'rejects properties reached through an array schema' do
      item = { 'type' => 'object', 'properties' => { 'region' => region } }
      definition = tool('routes' => { 'type' => 'array', 'items' => item })

      expect(described_class.valid?(definition)).to be(false)
    end

    it 'rejects properties reached through a composition schema' do
      branch = { 'type' => 'object', 'properties' => { 'region' => region } }
      definition = tool('routing' => { 'anyOf' => [branch] })

      expect(described_class.valid?(definition)).to be(false)
    end

    it 'rejects an annotation in a referenced definition' do
      definition = tool('routing' => { '$ref' => '#/$defs/routing' })
      definition['inputSchema']['$defs'] = {
        'routing' => { 'type' => 'object', 'properties' => { 'region' => region } }
      }

      expect(described_class.valid?(definition)).to be(false)
    end

    it 'accepts schemas without annotations under composition and array keywords' do
      item = { 'anyOf' => [{ 'type' => 'string' }, { 'type' => 'null' }] }
      definition = tool('routes' => { 'type' => 'array', 'items' => item })

      expect(described_class.valid?(definition)).to be(true)
      expect(described_class.for(definition, { routes: ['us-west1'] })).to eq({})
    end

    %w[default const enum examples].each do |keyword|
      it "does not mistake #{keyword} data for a schema declaration" do
        data = { 'x-mcp-header' => 'Bad Name' }
        value = %w[enum examples].include?(keyword) ? [data] : data
        definition = tool('routing' => { keyword => value })

        expect(described_class.valid?(definition)).to be(true)
        expect(described_class.for(definition, {})).to eq({})
      end
    end

    it 'does not mistake a property named x-mcp-header for an annotation' do
      definition = tool('x-mcp-header' => { 'type' => 'string' })

      expect(described_class.valid?(definition)).to be(true)
      expect(described_class.for(definition, { 'x-mcp-header' => 'Bad Name' })).to eq({})
    end

    it 'accepts boolean schemas without declarations' do
      definition = tool('enabled' => true, 'disabled' => false)

      expect(described_class.valid?(definition)).to be(true)
      expect(described_class.for(definition, {})).to eq({})
    end
  end
end
