# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::MCP::Client do
  let(:server) { File.expand_path('../../fixtures/mcp/server.rb', __dir__) }
  let(:client) { described_class.new(RubyLLM::MCP::Stdio.new([RbConfig.ruby, server], env:)) }
  let(:env) { {} }

  after { client.close }

  context 'with a 2026-07-28 server' do
    it 'discovers the server' do
      expect(client.server).to include('instructions' => 'A server for specs.')
      expect(client).to be_modern
    end

    it 'sends the protocol version, client info, and capabilities with every request' do
      meta = client.request('meta/echo')['meta']

      expect(meta).to include(
        'io.modelcontextprotocol/protocolVersion' => '2026-07-28',
        'io.modelcontextprotocol/clientInfo' => { 'name' => 'ruby_llm', 'version' => RubyLLM::VERSION },
        'io.modelcontextprotocol/clientCapabilities' => {}
      )
    end

    it 'follows pagination cursors' do
      names = client.list('tools/list', 'tools').map { |tool| tool['name'] }

      expect(names).to eq(%w[echo add fail picture slow wait deploy connect delete_everything])
    end

    it 'raises JSON-RPC errors with their code' do
      expect { client.request('unknown/method') }
        .to raise_error(RubyLLM::MCP::Error, 'Method not found') { |error| expect(error.code).to eq(-32_601) }
    end
  end

  context 'with a server that predates 2026-07-28' do
    let(:env) { { 'MCP_ERA' => 'legacy' } }

    it 'falls back to the initialize handshake' do
      expect(client.server).to include('serverInfo' => { 'name' => 'spec-server', 'version' => '0.9.0' })
      expect(client.version).to eq('2025-06-18')
      expect(client).not_to be_modern
    end

    it 'works after the handshake' do
      expect(client.list('tools/list', 'tools').size).to eq(9)
    end
  end
end
