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

    def paged_transport(*cursors)
      requests = []
      transport = Object.new
      transport.define_singleton_method(:requests) { requests }
      transport.define_singleton_method(:request) do |message, **|
        requests << message
        next { 'result' => { 'supportedVersions' => ['2026-07-28'] } } if message[:method] == 'server/discover'

        { 'result' => { 'tools' => ['search'], 'nextCursor' => cursors.shift } }
      end
      transport
    end

    def sent_cursors(transport)
      transport.requests.map { |message| message.dig(:params, :cursor) }
    end

    [nil, false].each do |cursor|
      it "stops at a cursor of #{cursor.inspect}" do
        transport = paged_transport(cursor, 'unreachable')

        expect(described_class.new(transport).list('tools/list', 'tools')).to eq(['search'])
      end
    end

    it 'follows an empty cursor' do
      transport = paged_transport('', nil)

      expect(described_class.new(transport).list('tools/list', 'tools')).to eq(%w[search search])
      expect(sent_cursors(transport).last).to eq('')
    end

    it 'follows a repeated cursor to the last page' do
      stub_const("#{described_class}::PAGE_LIMIT", 2)
      transport = paged_transport('same', 'same', nil)

      expect(described_class.new(transport).list('tools/list', 'tools')).to eq(%w[search search search])
    end

    it 'raises when a list does not end' do
      stub_const("#{described_class}::PAGE_LIMIT", 2)
      transport = paged_transport('same', 'same', 'same', 'unreachable')

      expect { described_class.new(transport).list('tools/list', 'tools') }
        .to raise_error(RubyLLM::MCP::Error, 'The server did not finish tools/list in 2 pages')
      expect(sent_cursors(transport).count('same')).to eq(2)
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

    it 'shakes hands with a server that rejects the revision without listing any' do
      server = fake_server.new do |method|
        if method == 'initialize'
          handshake('2025-06-18')
        else
          { 'error' => { 'code' => -32_022, 'message' => 'Unsupported protocol version' } }
        end
      end
      mcp_client = described_class.new(server)

      mcp_client.server

      expect(mcp_client.version).to eq('2025-06-18')
      expect(server.sent).to eq(['server/discover', 'initialize', 'notifications/initialized'])
    end

    it 'shakes hands with a server that rejects the revision while listing an older one' do
      server = fake_server.new do |method|
        method == 'initialize' ? handshake('2025-11-25') : unsupported('2025-11-25', '2025-06-18')
      end
      mcp_client = described_class.new(server)

      mcp_client.server

      expect(mcp_client.version).to eq('2025-11-25')
      expect(server.sent).to eq(['server/discover', 'initialize', 'notifications/initialized'])
    end

    it 'does not shake hands with a server that lists no version it speaks' do
      server = fake_server.new { unsupported('2027-01-01') }

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

  describe 'sessions that end' do
    let(:ending_server) do
      Class.new do
        attr_reader :sent

        def initialize
          @sent = Queue.new
          @session = 0
          @ended = []
          @pauses = Queue.new
          @holds = Queue.new
          @held = Queue.new
          @released = Queue.new
        end

        def end_session = @ended << @session
        def pause(count) = count.times { @pauses << true }
        def hold(count) = count.times { @holds << true }
        def held = @held.pop
        def release = @released << true

        def request(message, **)
          @sent << message[:method]
          case message[:method]
          when 'server/discover'
            { 'id' => message[:id], 'error' => { 'code' => -32_601, 'message' => 'Not found' } }
          when 'initialize' then start_session(message)
          else
            wait(@pauses)
            { 'id' => message[:id], 'result' => { 'session' => current_session } }
          end
        end

        def listen(*, **)
          hold(1)
          current_session
        end

        def notify(message, **) = @sent << message[:method]
        def cancel(*, **) = nil
        def close = @closed = true
        def session = (@session unless @closed)

        private

        def start_session(message)
          @closed = false
          @session += 1
          { 'id' => message[:id], 'result' => { 'protocolVersion' => '2025-06-18', 'capabilities' => {} } }
        end

        def current_session
          session = @session
          wait(@holds)
          raise RubyLLM::MCP::SessionExpired.new('ended', session:) if @ended.include?(session)

          session
        end

        def wait(gates)
          return unless gates.pop(timeout: 0)

          @held << true
          @released.pop
        end
      end
    end

    let(:server) { ending_server.new }
    let(:mcp_client) { described_class.new(server).tap(&:server) }

    def sent_since_last_check
      methods = []
      methods << server.sent.pop until server.sent.empty?
      methods
    end

    def finish(thread)
      thread.join(5) or raise 'thread did not finish'
      thread.value
    end

    it 'starts a new session when a request finds the old one ended' do
      mcp_client
      server.end_session

      expect(mcp_client.request('tools/list')).to eq('session' => 2)
    end

    it 'starts a new session when the client closes while a request finds the old one ended' do
      mcp_client
      server.end_session
      server.hold(1)

      request = Thread.new { mcp_client.request('tools/list') }
      server.held
      mcp_client.close
      server.release

      expect(finish(request)).to eq('session' => 2)
    end

    it 'starts one new session when requests on two threads find the old one ended' do
      mcp_client
      sent_since_last_check
      server.end_session
      server.hold(2)

      threads = Array.new(2) { Thread.new { mcp_client.request('tools/list') } }
      2.times { server.held }
      2.times { server.release }

      expect(threads.map { |thread| finish(thread) }).to eq([{ 'session' => 2 }, { 'session' => 2 }])
      expect(sent_since_last_check.count('initialize')).to eq(1)
    end

    it 'starts a new session when a request is sent on a session another thread started and that one ends' do
      mcp_client
      server.end_session
      server.pause(1)

      request = Thread.new { mcp_client.request('tools/list') }
      server.held
      expect(mcp_client.request('tools/list')).to eq('session' => 2)
      server.end_session
      server.release

      expect(finish(request)).to eq('session' => 3)
    end

    it 'keeps the new session a request started while a listener waited on the old one' do
      listener = Thread.new { mcp_client.listen({}) { nil } }
      server.held
      sent_since_last_check
      server.end_session
      expect(mcp_client.request('tools/list')).to eq('session' => 2)
      server.release

      expect { finish(listener) }.to raise_error(RubyLLM::MCP::SessionExpired)
      expect(sent_since_last_check.count('initialize')).to eq(1)
      expect(mcp_client.request('tools/list')).to eq('session' => 2)
    end

    it 'starts a new session when the session a listener recovered ends too' do
      mcp_client
      server.end_session
      listener = Thread.new { mcp_client.listen({}) { nil } }
      server.held
      sent_since_last_check
      server.end_session
      server.release

      expect { finish(listener) }.to raise_error(RubyLLM::MCP::SessionExpired)
      expect(sent_since_last_check.count('initialize')).to eq(1)
      expect(mcp_client.request('tools/list')).to eq('session' => 3)
    end
  end
end
