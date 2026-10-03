# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::XAI::Responses do
  it 'uses portable MCP server names and URLs' do
    protocol = described_class.allocate
    alias_definition = protocol.server_tool_aliases.fetch(:mcp).call(name: 'docs', url: 'https://example.test/mcp')

    expect(alias_definition).to eq(tool: { type: 'mcp', server_label: 'docs', server_url: 'https://example.test/mcp' })
  end

  include_context 'with configured RubyLLM'

  it 'preserves collection source references alongside web citations' do
    source = 'collections://collection_1/files/file_facts'
    protocol = described_class.new(RubyLLM::Providers::XAI.new(RubyLLM.config))
    message = protocol.send(:parse_completion_body, {
                              'status' => 'completed', 'output' => [],
                              'citations' => [source, 'https://ruby-lang.org']
                            }, raw: nil)

    expect(message.citations).to contain_exactly(
      have_attributes(url: source, source_index: 0),
      have_attributes(url: 'https://ruby-lang.org', source_index: 1)
    )
  end

  it 'preserves collection citations from completed streams' do
    source = 'collections://collection_1/files/file_facts'
    protocol = described_class.new(RubyLLM::Providers::XAI.new(RubyLLM.config))
    chunk = protocol.send(:build_chunk, {
                            'type' => 'response.completed',
                            'response' => { 'status' => 'completed', 'output' => [], 'citations' => [source] }
                          })

    expect(chunk.citations.first).to have_attributes(url: source, source_index: 0)
  end

  describe 'server tool use' do
    let(:protocol) { described_class.new(RubyLLM::Providers::XAI.new(RubyLLM.config)) }
    let(:usage) do
      {
        'input_tokens' => 12_540, 'output_tokens' => 486, 'num_sources_used' => 0, 'num_server_side_tools_used' => 3,
        'server_side_tool_usage_details' => {
          'web_search_calls' => 2, 'x_search_calls' => 0, 'code_interpreter_calls' => 1, 'file_search_calls' => 0,
          'mcp_calls' => 0, 'document_search_calls' => 0, 'image_generation_calls' => 0
        }
      }
    end

    it 'names each tool that ran the way other providers do' do
      message = protocol.send(:parse_completion_body, { 'status' => 'completed', 'output' => [], 'usage' => usage },
                              raw: nil)

      expect(message.tokens.server_tool_use).to eq('web_search_requests' => 2, 'code_execution_requests' => 1)
    end

    it 'counts the tools a completed stream reports' do
      chunk = protocol.send(:build_chunk, {
                              'type' => 'response.completed',
                              'response' => { 'status' => 'completed', 'output' => [], 'usage' => usage }
                            })

      expect(chunk.tokens.server_tool_use).to eq('web_search_requests' => 2, 'code_execution_requests' => 1)
    end
  end

  describe '#parse_usage' do
    let(:protocol) do
      described_class.new(RubyLLM::Providers::XAI.new(RubyLLM.config))
    end

    it 'converts cost_in_usd_ticks into a reported cost in dollars' do
      usage = protocol.send(:parse_usage,
                            { 'input_tokens' => 10, 'output_tokens' => 5, 'cost_in_usd_ticks' => 2_909_000 })

      expect(usage[:reported_cost]).to be_within(1e-12).of(0.0002909)
    end

    it 'leaves reported cost nil when ticks are absent' do
      usage = protocol.send(:parse_usage, { 'input_tokens' => 10 })

      expect(usage[:reported_cost]).to be_nil
    end
  end
end
