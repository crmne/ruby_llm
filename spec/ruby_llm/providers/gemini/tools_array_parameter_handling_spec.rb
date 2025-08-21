# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/tool'

RSpec.describe RubyLLM::Providers::Gemini::Tools do
  let(:provider_class) do
    Class.new do
      include RubyLLM::Providers::Gemini::Tools
    end
  end

  let(:provider) { provider_class.new }

  it 'properly formats tools with array parameters for Gemini API' do
    # Define a tool with array parameter similar to the error case
    tool_with_array = Class.new(RubyLLM::Tool) do
      def self.name
        'DataFetcher'
      end

      description 'Fetches data with specific fields'
      param :fields, type: 'array', desc: 'List of fields to return', required: true

      def execute(fields:)
        { selected_fields: fields }
      end
    end

    # Another tool with array parameter
    another_tool = Class.new(RubyLLM::Tool) do
      def self.name
        'FilterTool'
      end

      description 'Filters data by criteria'
      param :fields, type: 'array', desc: 'Fields to filter on', required: true
      param :query, type: 'string', desc: 'Query string', required: false

      def execute(fields:, query: nil)
        { filtered_fields: fields, query: query }
      end
    end

    tools = {
      data_fetcher: tool_with_array.new,
      filter: another_tool.new
    }

    result = provider.send(:format_tools, tools)

    # Verify the structure matches what Gemini expects
    expect(result).to be_an(Array)
    expect(result.first).to have_key(:functionDeclarations)

    function_decls = result.first[:functionDeclarations]
    expect(function_decls).to be_an(Array)
    expect(function_decls.size).to eq(2)

    # Check first tool (data_fetcher)
    first_tool = function_decls[0]
    expect(first_tool[:name]).to eq('data_fetcher')
    expect(first_tool[:description]).to eq('Fetches data with specific fields')
    expect(first_tool[:parameters][:type]).to eq('OBJECT')

    # Most important: verify the array parameter has the 'items' field
    fields_param = first_tool[:parameters][:properties][:fields]
    expect(fields_param).to eq({
                                 type: 'ARRAY',
                                 description: 'List of fields to return',
                                 items: { type: 'STRING' }
                               })

    expect(first_tool[:parameters][:required]).to contain_exactly('fields')

    # Check second tool (filter)
    second_tool = function_decls[1]
    expect(second_tool[:name]).to eq('filter')

    # Verify array parameter in second tool also has 'items'
    filter_fields_param = second_tool[:parameters][:properties][:fields]
    expect(filter_fields_param).to include(
      type: 'ARRAY',
      items: { type: 'STRING' }
    )

    # Verify string parameter doesn't have items
    query_param = second_tool[:parameters][:properties][:query]
    expect(query_param).to eq({
                                type: 'STRING',
                                description: 'Query string'
                              })
    expect(query_param).not_to have_key(:items)

    # Only required field should be in required array
    expect(second_tool[:parameters][:required]).to contain_exactly('fields')
  end

  it 'handles tools without array parameters correctly' do
    simple_tool = Class.new(RubyLLM::Tool) do
      def self.name
        'SimpleTool'
      end

      description 'A simple tool'
      param :name, type: 'string', desc: 'Name parameter'
      param :count, type: 'integer', desc: 'Count parameter'

      def execute(name:, count:)
        { name: name, count: count }
      end
    end

    tools = { simple: simple_tool.new }
    result = provider.send(:format_tools, tools)

    function_decl = result.first[:functionDeclarations].first

    # Verify non-array parameters don't have items field
    name_param = function_decl[:parameters][:properties][:name]
    expect(name_param).to eq({
                               type: 'STRING',
                               description: 'Name parameter'
                             })
    expect(name_param).not_to have_key(:items)

    count_param = function_decl[:parameters][:properties][:count]
    expect(count_param).to eq({
                                type: 'NUMBER',
                                description: 'Count parameter'
                              })
    expect(count_param).not_to have_key(:items)
  end
end
