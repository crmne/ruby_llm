# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::MCP::ParamHeaders do
  def tool(properties)
    { 'name' => 'query', 'inputSchema' => { 'type' => 'object', 'properties' => properties } }
  end

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
end
