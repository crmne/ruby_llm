# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::MCP do
  describe 'TRANSPORTS' do
    it 'contains all transport types' do
      expect(described_class::TRANSPORTS).to eq(%i[stdio sse http sdk])
    end
  end

  describe RubyLLM::AgentSDK::MCP::Server do
    describe '.stdio' do
      it 'creates stdio transport server' do
        server = described_class.stdio(
          'filesystem',
          command: 'npx',
          args: ['-y', '@anthropic/mcp-server-filesystem', '/tmp'],
          env: { 'DEBUG' => '1' }
        )
        expect(server.name).to eq('filesystem')
        expect(server.transport).to eq(:stdio)
        expect(server.command).to eq('npx')
        expect(server.args).to eq(['-y', '@anthropic/mcp-server-filesystem', '/tmp'])
        expect(server.env).to eq({ 'DEBUG' => '1' })
      end
    end

    describe '.sse' do
      it 'creates SSE transport server' do
        server = described_class.sse('api', url: 'http://localhost:8080/sse')
        expect(server.name).to eq('api')
        expect(server.transport).to eq(:sse)
        expect(server.url).to eq('http://localhost:8080/sse')
      end
    end

    describe '.http' do
      it 'creates HTTP transport server' do
        server = described_class.http('api', url: 'http://localhost:8080/mcp')
        expect(server.name).to eq('api')
        expect(server.transport).to eq(:http)
        expect(server.url).to eq('http://localhost:8080/mcp')
      end
    end

    describe '.sdk' do
      it 'creates SDK transport server with tools' do
        tool = RubyLLM::AgentSDK::Tool.new(name: 'test', description: 'Test') { 'ok' }
        server = described_class.sdk('embedded', tools: [tool])
        expect(server.name).to eq('embedded')
        expect(server.transport).to eq(:sdk)
        expect(server.tools).to eq([tool])
      end
    end

    describe 'validation' do
      it 'raises for invalid transport' do
        expect {
          described_class.new(name: 'test', transport: :invalid)
        }.to raise_error(RubyLLM::AgentSDK::ConfigurationError, /Invalid transport/)
      end

      it 'raises when stdio missing command' do
        expect {
          described_class.new(name: 'test', transport: :stdio)
        }.to raise_error(RubyLLM::AgentSDK::ConfigurationError, /requires command/)
      end

      it 'raises when sse missing url' do
        expect {
          described_class.new(name: 'test', transport: :sse)
        }.to raise_error(RubyLLM::AgentSDK::ConfigurationError, /requires url/)
      end

      it 'raises when http missing url' do
        expect {
          described_class.new(name: 'test', transport: :http)
        }.to raise_error(RubyLLM::AgentSDK::ConfigurationError, /requires url/)
      end

      it 'raises when sdk missing tools' do
        expect {
          described_class.new(name: 'test', transport: :sdk)
        }.to raise_error(RubyLLM::AgentSDK::ConfigurationError, /requires tools/)
      end
    end

    describe '#to_h' do
      it 'returns hash for stdio server' do
        server = described_class.stdio('fs', command: 'node', args: ['server.js'])
        hash = server.to_h
        expect(hash[:type]).to eq('stdio')
        expect(hash[:command]).to eq('node')
        expect(hash[:args]).to eq(['server.js'])
      end

      it 'returns hash for http server' do
        server = described_class.http('api', url: 'http://localhost:8080')
        hash = server.to_h
        expect(hash[:type]).to eq('http')
        expect(hash[:url]).to eq('http://localhost:8080')
      end
    end
  end

  describe RubyLLM::AgentSDK::MCP::Servers do
    let(:servers) { described_class.new }
    let(:server1) { RubyLLM::AgentSDK::MCP::Server.http('api1', url: 'http://a') }
    let(:server2) { RubyLLM::AgentSDK::MCP::Server.http('api2', url: 'http://b') }

    describe '#add' do
      it 'adds server to collection' do
        servers.add(server1)
        expect(servers['api1']).to eq(server1)
      end

      it 'supports << operator' do
        servers << server1
        expect(servers.include?('api1')).to be true
      end
    end

    describe '#[]' do
      it 'retrieves server by name' do
        servers.add(server1)
        expect(servers['api1']).to eq(server1)
        expect(servers[:api1]).to eq(server1)
      end
    end

    describe '#each' do
      it 'iterates over all servers' do
        servers.add(server1)
        servers.add(server2)

        names = []
        servers.each { |s| names << s.name }
        expect(names).to contain_exactly('api1', 'api2')
      end
    end

    describe '#names' do
      it 'returns all server names' do
        servers.add(server1)
        servers.add(server2)
        expect(servers.names).to contain_exactly('api1', 'api2')
      end
    end

    describe '#to_h' do
      it 'returns hash of server configurations' do
        servers.add(server1)
        hash = servers.to_h
        expect(hash['api1'][:type]).to eq('http')
      end
    end

    describe '#to_mcp_json' do
      it 'returns .mcp.json format' do
        servers.add(server1)
        json = servers.to_mcp_json
        expect(json).to have_key(:mcpServers)
        expect(json[:mcpServers]).to have_key('api1')
      end
    end
  end
end
