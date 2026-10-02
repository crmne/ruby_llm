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

    it 'times out on a server that stops in the middle of a line' do
      stalled = described_class.new(RubyLLM::MCP::Stdio.new([RbConfig.ruby, server], timeout: 1))

      expect { stalled.request('spec/stall') }.to raise_error(RubyLLM::MCP::Error, /did not answer in time/)
    ensure
      stalled&.close
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

    it 'shakes hands again after closing' do
      client.list('tools/list', 'tools')
      client.close

      expect(client.list('tools/list', 'tools').size).to eq(9)
    end

    it 'reports a change once the request that carried it is answered, so the report can make requests' do
      sizes = []
      changing = described_class.new(RubyLLM::MCP::Stdio.new([RbConfig.ruby, server], env:)) do
        sizes << changing.list('tools/list', 'tools').size
      end

      changing.request('spec/change_tools')

      expect(sizes).to eq([10])
    ensure
      changing&.close
    end
  end

  describe 'protocol versions' do
    let(:fake_server) do
      Class.new do
        attr_reader :sent, :params

        def initialize(&answer)
          @answer = answer
          @sent = []
          @params = {}
        end

        def request(message, **)
          @sent << message[:method]
          @params[message[:method]] = message[:params]
          reply = @answer.call(message[:method], @sent.count(message[:method]))
          { 'jsonrpc' => '2.0', 'id' => message[:id] }.merge(reply)
        end

        def notify(message, **) = @sent << message[:method]
        def cancel(*, **) = nil
        def close = @closed = true
        def closed? = @closed == true
      end
    end

    def unsupported(*versions)
      { 'error' => { 'code' => -32_022, 'message' => 'Unsupported protocol version',
                     'data' => { 'supported' => versions, 'requested' => '2026-07-28' } } }
    end

    def handshake(version)
      { 'result' => { 'protocolVersion' => version, 'capabilities' => {} } }
    end

    def legacy(version)
      fake_server.new do |method|
        method == 'initialize' ? handshake(version) : { 'error' => { 'code' => -32_601, 'message' => 'Not found' } }
      end
    end

    it 'sends a request again when the server rejects a version it lists' do
      server = fake_server.new do |method, attempt|
        next unsupported('2026-07-28') if method == 'server/discover' && attempt == 1

        { 'result' => { 'supportedVersions' => ['2026-07-28'] } }
      end
      mcp_client = described_class.new(server)

      expect(mcp_client.server).to eq('supportedVersions' => ['2026-07-28'])
      expect(mcp_client).to be_modern
      expect(server.sent).to eq(['server/discover', 'server/discover'])
    end

    it 'sends a request again only once' do
      server = fake_server.new { unsupported('2026-07-28') }

      expect { described_class.new(server).server }.to raise_error(RubyLLM::MCP::Error, 'Unsupported protocol version')
      expect(server.sent).to eq(['server/discover', 'server/discover'])
    end

    it 'does not shake hands with a modern server that lists only older versions' do
      server = fake_server.new { unsupported('2025-11-25') }

      expect { described_class.new(server).server }.to raise_error(RubyLLM::MCP::Error, 'Unsupported protocol version')
      expect(server.sent).not_to include('initialize')
    end

    it 'speaks every version it knows from before 2026-07-28' do
      described_class::LEGACY_VERSIONS.each do |version|
        mcp_client = described_class.new(legacy(version))

        mcp_client.server

        expect(mcp_client.version).to eq(version)
      end
    end

    it 'declares only its extensions in the handshake' do
      server = legacy('2025-06-18')
      capabilities = { elicitation: { form: {} }, extensions: { 'com.example/audit' => {} } }

      described_class.new(server, capabilities:).server

      expect(server.params['initialize'][:capabilities]).to eq(extensions: { 'com.example/audit' => {} })
    end

    it 'disconnects from a server that answers the handshake with a version it does not speak' do
      server = legacy('2099-01-01')
      mcp_client = described_class.new(server)

      expect { mcp_client.server }.to raise_error(RubyLLM::MCP::Error, /protocol version 2099-01-01/)
      expect(mcp_client.version).to be_nil
      expect(server).to be_closed
      expect(server.sent).not_to include('notifications/initialized')
    end
  end

  context 'with a server that answers discovery without 2026-07-28' do
    let(:env) { { 'MCP_ERA' => 'discover_without_modern' } }

    it 'falls back to the initialize handshake' do
      expect(client.list('tools/list', 'tools').size).to eq(9)
      expect(client.version).to eq('2025-06-18')
    end
  end
end
