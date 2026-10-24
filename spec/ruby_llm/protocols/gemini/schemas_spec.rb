# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Schemas do
  def nested(levels, leaf = { 'type' => 'string' })
    (1..levels).reduce(leaf) do |schema, _|
      { 'type' => 'object', 'properties' => { 'child' => schema }, 'required' => ['child'] }
    end
  end

  def resolve(schema, node)
    return node unless node.is_a?(Hash) && node['$ref']

    resolve(schema, schema['$defs'].fetch(node['$ref'].delete_prefix('#/$defs/')))
  end

  def depth_of_values(schema, node = schema)
    node = resolve(schema, node)
    node['properties'] ? 1 + depth_of_values(schema, node['properties']['child']) : 0
  end

  describe '.nesting' do
    it 'counts objects and arrays' do
      expect(described_class.nesting({ 'a' => [[{ 'b' => 1 }]] })).to eq(4)
    end
  end

  describe '.render_schema' do
    it 'sends a schema as deep as Gemini accepts as it is' do
      schema = nested(15, { 'type' => 'string', 'enum' => ['a'] })

      expect(described_class.nesting(schema)).to eq(described_class::MAX_DEPTH)
      expect(described_class.render_schema(schema)).to equal(schema)
    end

    it 'moves the deep subschemas of a deeper schema into $defs' do
      rendered = described_class.render_schema(nested(20))

      expect(described_class.nesting(rendered)).to eq(17)
      expect(rendered['$defs'].keys).to all(start_with('nested'))
      expect(depth_of_values(rendered)).to eq(20)
    end

    it 'moves a subschema from the 16th level on' do
      rendered = described_class.render_schema(nested(7, { 'type' => 'array', 'items' => nested(10) }))

      expect(described_class.nesting(rendered)).to eq(17)
    end

    it 'moves the deep subschemas of a deep definition too' do
      schema = { 'type' => 'object', 'properties' => { 'tree' => { '$ref' => '#/$defs/Tree' } },
                 '$defs' => { 'Tree' => nested(20) } }

      expect(described_class.nesting(described_class.render_schema(schema))).to be <= described_class::MAX_DEPTH
    end

    it 'keeps boolean subschemas where they are' do
      schema = nested(20, { 'type' => 'object', 'additionalProperties' => false })

      rendered = described_class.render_schema(schema)

      expect(described_class.nesting(rendered)).to be <= described_class::MAX_DEPTH
      expect(JSON.generate(rendered)).to include('"additionalProperties":false')
    end

    it 'moves the subschemas of a schema that references other documents' do
      schema = nested(20, { '$ref' => 'https://example.com/tag.json' })

      expect(described_class.nesting(described_class.render_schema(schema))).to be <= described_class::MAX_DEPTH
    end

    it 'keeps the definitions a schema already has, and their references' do
      leaf = { 'type' => 'string', 'minLength' => 2 }
      schema = nested(20, { '$ref' => '#/$defs/Leaf' }).merge('$defs' => { 'Leaf' => leaf })

      rendered = described_class.render_schema(schema)

      expect(rendered['$defs']['Leaf']).to eq('type' => 'string', 'minLength' => 2)
      expect(described_class.nesting(rendered)).to be <= described_class::MAX_DEPTH
    end

    it 'reaches subschemas inside unions and arrays' do
      union = (1..11).reduce({ 'type' => 'string' }) do |schema, _|
        { 'anyOf' => [{ 'type' => 'array', 'items' => schema }, { 'type' => 'null' }] }
      end

      rendered = described_class.render_schema({ 'type' => 'object', 'properties' => { 'tags' => union } })

      expect(described_class.nesting(rendered)).to be <= described_class::MAX_DEPTH
    end

    it 'writes symbol keys as strings' do
      rendered = described_class.render_schema(RubyLLM::Support::Utils.deep_symbolize_keys(nested(20)))

      expect(rendered.keys).to include('properties', '$defs')
    end

    it 'leaves a schema alone when a reference points inside a definition' do
      schema = { 'type' => 'object', 'properties' => { 'leaf' => { '$ref' => '#/$defs/Tree/properties/child' } },
                 '$defs' => { 'Tree' => nested(20) } }

      expect(described_class.render_schema(schema)).to eq(schema)
    end

    it 'leaves a schema alone when a subschema starts a resource of its own' do
      schema = nested(20, { '$id' => 'https://example.com/leaf.json', 'type' => 'string' })

      expect(described_class.render_schema(schema)).to eq(schema)
    end

    it 'moves the subschemas of a schema that names itself' do
      schema = nested(20).merge('$id' => 'https://example.com/tree.json')

      expect(described_class.nesting(described_class.render_schema(schema))).to be <= described_class::MAX_DEPTH
    end

    it 'leaves a schema alone when moving its subschemas would break a reference into it' do
      properties = nested(20)['properties'].merge('copy' => { '$ref' => '#/properties/child' })
      schema = nested(20).merge('properties' => properties)

      expect(described_class.render_schema(schema)).to eq(schema)
    end
  end

  it 'renders deep tool parameters and structured output schemas within the limit' do
    tool = Class.new(RubyLLM::Tool) do
      description 'Saves a tree'

      def name = 'save_tree'
    end.new
    allow(tool).to receive(:parameters_schema).and_return(nested(20))
    renderer = Object.new.tap { |obj| obj.extend(RubyLLM::Protocols::Gemini::Chat, RubyLLM::Protocols::Gemini::Tools) }

    declaration = renderer.render_tools({ 'save_tree' => tool }).first[:functionDeclarations].first
    output = renderer.send(:build_json_schema, { schema: nested(20) })

    expect(described_class.nesting(declaration[:parametersJsonSchema])).to be <= described_class::MAX_DEPTH
    expect(described_class.nesting(output)).to be <= described_class::MAX_DEPTH
  end
end
