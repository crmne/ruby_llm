# frozen_string_literal: true

require 'spec_helper'
require_relative '../../support/mcp_stream_server'

RSpec.describe RubyLLM::MCP::HTTP do
  let(:url) { 'https://mcp.example.com/mcp' }
  let(:client) { RubyLLM::MCP::Client.new(described_class.new(url, headers: { 'Authorization' => 'Bearer secret' })) }

  def json_rpc(result: nil, error: nil)
    ->(request) { { jsonrpc: '2.0', id: JSON.parse(request.body)['id'], result:, error: }.compact.to_json }
  end

  def stub_method(method, status: 200, headers: { 'Content-Type' => 'application/json' }, body: nil, **reply)
    stub_request(:post, url)
      .with { |request| JSON.parse(request.body)['method'] == method }
      .to_return(status:, headers:, body: body || json_rpc(**reply))
  end

  def discover_result
    { resultType: 'complete', supportedVersions: ['2026-07-28'], capabilities: { tools: {} } }
  end

  it 'refuses plain HTTP outside loopback addresses' do
    expect { described_class.new('http://mcp.example.com/mcp') }.to raise_error(ArgumentError, /HTTPS/)
    expect { described_class.new('http://localhost:3000/mcp') }.not_to raise_error
  end

  it 'refuses URLs that carry credentials' do
    expect { described_class.new('https://mcp.example.com@attacker.io/mcp') }
      .to raise_error(ArgumentError, /credentials/)
  end

  it 'sends the MCP headers with each request' do
    stub_method('server/discover', result: discover_result)
    stub_method('tools/call', result: { content: [] })

    client.request('tools/call', { name: 'search', arguments: {} })

    expect(
      a_request(:post, url).with(headers: {
                                   'Mcp-Protocol-Version' => '2026-07-28', 'Mcp-Method' => 'tools/call',
                                   'Mcp-Name' => 'search', 'Authorization' => 'Bearer secret'
                                 })
    ).to have_been_made
  end

  it 'names the task in the Mcp-Name header of task requests' do
    stub_method('server/discover', result: discover_result)
    stub_method('tasks/get', result: { resultType: 'complete', taskId: 'task-1', status: 'working' })

    client.request('tasks/get', { taskId: 'task-1' })

    expect(a_request(:post, url).with(headers: { 'Mcp-Method' => 'tasks/get', 'Mcp-Name' => 'task-1' }))
      .to have_been_made
  end

  it 'sends mirrored tool arguments as Mcp-Param headers' do
    stub_method('server/discover', result: discover_result)
    stub_method('tools/call', result: { content: [] })

    client.request('tools/call', { name: 'query', arguments: {} }, headers: { 'Region' => ' us-west1' })

    encoded = "=?base64?#{Base64.strict_encode64(' us-west1')}?="
    expect(a_request(:post, url).with(headers: { 'Mcp-Param-Region' => encoded })).to have_been_made
  end

  it 'encodes header values that are not plain ASCII' do
    stub_method('server/discover', result: discover_result)
    stub_method('resources/read', result: { contents: [] })

    client.request('resources/read', { uri: 'file:///Überblick.md' })

    encoded = "=?base64?#{Base64.strict_encode64('file:///Überblick.md')}?="
    expect(a_request(:post, url).with(headers: { 'Mcp-Name' => encoded })).to have_been_made
  end

  it 'reads responses sent as an event stream and yields their notifications' do
    stub_method('server/discover', result: discover_result)
    stub_method('tools/call', headers: { 'Content-Type' => 'text/event-stream' }, body: lambda { |request|
      id = JSON.parse(request.body)['id']
      progress = { jsonrpc: '2.0', method: 'notifications/progress', params: { progress: 1, total: 2 } }
      result = { jsonrpc: '2.0', id:, result: { content: [{ type: 'text', text: 'done' }] } }
      "event: message\ndata: #{progress.to_json}\n\nevent: message\ndata: #{result.to_json}\n\n"
    })
    notifications = []

    result = client.request('tools/call', { name: 'slow', arguments: {} }) { |message| notifications << message }

    expect(result).to eq('content' => [{ 'type' => 'text', 'text' => 'done' }])
    expect(notifications.map { |message| message['method'] }).to eq(['notifications/progress'])
  end

  it 'goes on with a call when the server refuses the answer to its own request' do
    stub_method('server/discover', result: discover_result)
    stub_request(:post, url).with { |request| JSON.parse(request.body)['id'] == 'roots-1' }.to_return(status: 401)
    stub_method('tools/call', headers: { 'Content-Type' => 'text/event-stream' }, body: lambda { |request|
      ask = { jsonrpc: '2.0', id: 'roots-1', method: 'roots/list' }
      result = { jsonrpc: '2.0', id: JSON.parse(request.body)['id'], result: { content: [] } }
      "data: #{ask.to_json}\n\ndata: #{result.to_json}\n\n"
    })

    expect(client.request('tools/call', { name: 'deploy' })).to eq('content' => [])
  end

  it 'falls back to the initialize handshake when the server does not know server/discover' do
    stub_method('server/discover', status: 400, body: 'Bad Request: missing session')
    stub_method('initialize', headers: { 'Content-Type' => 'application/json', 'Mcp-Session-Id' => 'session-1' },
                              result: { protocolVersion: '2025-06-18', capabilities: {} })
    stub_method('notifications/initialized', status: 202, body: '')
    stub_method('tools/list', result: { tools: [] })

    client.request('tools/list')

    expect(client.version).to eq('2025-06-18')
    expect(
      a_request(:post, url).with(headers: { 'Mcp-Session-Id' => 'session-1', 'Mcp-Protocol-Version' => '2025-06-18' })
    ).to have_been_made.twice
  end

  it 'does not fall back when a modern server rejects the protocol version' do
    stub_method('server/discover', status: 400, error: {
                  code: -32_022, message: 'Unsupported protocol version', data: { supported: ['2027-01-01'] }
                })

    expect { client.server }.to raise_error(RubyLLM::MCP::Error, 'Unsupported protocol version')
    expect(a_request(:post, url).with { |request| request.body.include?('initialize') }).not_to have_been_made
  end

  describe 'cancellation' do
    let(:cancel) { -> { raise RubyLLM::CancelledError } }

    before do
      stub_method('tools/call', headers: { 'Content-Type' => 'text/event-stream' },
                                body: "event: message\ndata: {}\n\n")
      stub_method('notifications/cancelled', status: 202, body: '')
    end

    it 'closes the stream of a 2026-07-28 request' do
      stub_method('server/discover', result: discover_result)

      expect { RubyLLM::Support::Cancellation.watch(cancel) { client.request('tools/call', { name: 'slow' }) } }
        .to raise_error(RubyLLM::CancelledError)
      expect(a_request(:post, url).with { |request| request.body.include?('notifications/cancelled') })
        .not_to have_been_made
    end

    it 'tells an older server that the request is cancelled' do
      stub_method('server/discover', status: 404, body: '')
      stub_method('initialize', result: { protocolVersion: '2025-06-18', capabilities: {} })
      stub_method('notifications/initialized', status: 202, body: '')

      client.server
      expect { RubyLLM::Support::Cancellation.watch(cancel) { client.request('tools/call', { name: 'slow' }) } }
        .to raise_error(RubyLLM::CancelledError)
      expect(a_request(:post, url).with { |request| request.body.include?('notifications/cancelled') })
        .to have_been_made
    end
  end

  describe 'sessions of older servers' do
    let(:ended) { [] }

    before do
      sessions = 0
      stub_request(:post, url).to_return do |request|
        body = JSON.parse(request.body)
        case body['method']
        when 'server/discover' then { status: 404, body: '' }
        when 'initialize'
          sessions += 1
          { headers: { 'Content-Type' => 'application/json', 'Mcp-Session-Id' => "session-#{sessions}" },
            body: json_rpc(result: { protocolVersion: '2025-06-18', capabilities: {} }).call(request) }
        else
          next { status: 202, body: '' } unless body['id']
          next { status: 404, body: '' } if ended.include?(request.headers['Mcp-Session-Id'])

          { headers: { 'Content-Type' => 'application/json' }, body: json_rpc(result: { tools: [] }).call(request) }
        end
      end
    end

    def initializations
      a_request(:post, url).with do |request|
        JSON.parse(request.body)['method'] == 'initialize' && !request.headers.key?('Mcp-Session-Id')
      end
    end

    it 'starts a new session when the server ends the old one' do
      client.request('tools/list')
      ended << 'session-1'

      expect(client.request('tools/list')).to eq('tools' => [])
      expect(initializations).to have_been_made.twice
      expect(a_request(:post, url).with(headers: { 'Mcp-Session-Id' => 'session-2' })).to have_been_made.twice
    end

    it 'gives up when the new session ends too' do
      client.request('tools/list')
      ended.push('session-1', 'session-2')

      expect { client.request('tools/list') }.to raise_error(RubyLLM::MCP::Error, 'mcp.example.com ended the session')
      expect(initializations).to have_been_made.twice
    end

    it 'gives callable headers the HTTP method of each request' do
      verbs = []
      headers = lambda do |verb|
        verbs << verb
        {}
      end
      client = RubyLLM::MCP::Client.new(described_class.new(url, headers:))
      stub_request(:get, url).to_return(status: 405)
      stub_request(:delete, url).to_return(status: 204)

      client.request('tools/list')
      expect { client.listen({}) { nil } }.to raise_error(RubyLLM::MCP::Error, 'mcp.example.com sends no events')
      client.close

      expect(verbs.uniq).to eq(%w[POST GET DELETE])
    end

    it 'ends the session when it closes' do
      stub_request(:delete, url).to_return(status: 405)
      client.request('tools/list')

      client.close

      expect(a_request(:delete, url).with(headers: {
                                            'Mcp-Session-Id' => 'session-1', 'MCP-Protocol-Version' => '2025-06-18',
                                            'Authorization' => 'Bearer secret'
                                          })).to have_been_made
      client.request('tools/list')
      expect(initializations).to have_been_made.twice
    end

    it 'keeps the session when the adapter passes no response to on_data, as Faraday 1 does' do
      adapter = Class.new(Faraday::Adapter::NetHttp) do
        def call(env)
          on_data = env.request.on_data
          env.request.on_data = ->(chunk, size, _env = nil) { on_data.call(chunk, size) }
          super
        end
      end
      config = RubyLLM.config.dup.tap { |copy| copy.faraday_adapter = adapter }

      RubyLLM::MCP::Client.new(described_class.new(url, config:)).request('tools/list')

      expect(a_request(:post, url).with(headers: { 'Mcp-Session-Id' => 'session-1' })).to have_been_made.twice
    end
  end

  describe 'streams that end before the answer' do
    let(:events) { { 'Content-Type' => 'text/event-stream' } }
    let(:progress) { { jsonrpc: '2.0', method: 'notifications/progress', params: { progress: 1 } }.to_json }

    def event(data = '', id: nil, retry_after: nil)
      fields = { id:, retry: retry_after, data: }.compact
      "#{fields.map { |field, value| "#{field}: #{value}" }.join("\n")}\n\n"
    end

    def answer(request)
      { jsonrpc: '2.0', id: JSON.parse(request.body)['id'], result: { content: [] } }.to_json
    end

    def calls
      a_request(:post, url).with { |request| JSON.parse(request.body)['method'] == 'tools/call' }
    end

    def monotonic_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    context 'with a 2026-07-28 server' do
      before { stub_method('server/discover', result: discover_result) }

      it 'sends the request again with a new ID' do
        ids = []
        stub_method('tools/call', headers: events, body: lambda { |request|
          ids << JSON.parse(request.body)['id']
          ids.one? ? event(progress) : event(answer(request))
        })

        expect(client.request('tools/call', { name: 'slow' })).to eq('content' => [])
        expect(ids.uniq.size).to eq(2)
        expect(a_request(:get, url)).not_to have_been_made
      end

      it 'gives up after a few attempts' do
        stub_method('tools/call', headers: events, body: event(progress))

        expect { client.request('tools/call', { name: 'slow' }) }
          .to raise_error(RubyLLM::MCP::Error, 'mcp.example.com did not answer tools/call')
        expect(calls).to have_been_made.times(4)
      end

      it 'skips event data that is not a JSON-RPC message' do
        stub_method('tools/call', headers: events, body: ->(request) { event('"keep-alive"') + event(answer(request)) })

        expect(client.request('tools/call', { name: 'slow' })).to eq('content' => [])
      end

      it 'does not send the request again after a JSON body without the answer' do
        stub_method('tools/call', body: { jsonrpc: '2.0', id: 'another', result: {} }.to_json)

        expect { client.request('tools/call', { name: 'slow' }) }.to raise_error(RubyLLM::MCP::Error, /did not answer/)
        expect(calls).to have_been_made.once
      end
    end

    context 'with an older server' do
      before do
        stub_method('server/discover', status: 404, body: '')
        stub_method('initialize', headers: { 'Content-Type' => 'application/json', 'Mcp-Session-Id' => 'session-1' },
                                  result: { protocolVersion: '2025-11-25', capabilities: {} })
        stub_method('notifications/initialized', status: 202, body: '')
      end

      it 'resumes the stream from its last event after the wait the server asks for' do
        call = nil
        stub_method('tools/call', headers: events, body: lambda { |request|
          call = request
          event(id: 'event-1', retry_after: 200) + event(progress, id: 'event-2')
        })
        stub_request(:get, url).to_return(headers: events, body: ->(_) { event(answer(call), id: 'event-3') })
        notifications = []
        started = monotonic_now

        result = client.request('tools/call', { name: 'slow' }) { |message| notifications << message }

        expect(result).to eq('content' => [])
        expect(monotonic_now - started).to be >= 0.2
        expect(notifications.map { |message| message['method'] }).to eq(['notifications/progress'])
        expect(a_request(:get, url).with(headers: {
                                           'Accept' => 'text/event-stream', 'Last-Event-ID' => 'event-2',
                                           'Mcp-Session-Id' => 'session-1', 'MCP-Protocol-Version' => '2025-11-25',
                                           'Authorization' => 'Bearer secret'
                                         })).to have_been_made.once
        expect(calls).to have_been_made.once
      end

      it 'resumes from an event ID and wait the server sends without data' do
        call = nil
        stub_method('tools/call', headers: events, body: lambda { |request|
          call = request
          "#{event(progress)}id: event-2\nretry: 200\n\n"
        })
        stub_request(:get, url).to_return(headers: events, body: ->(_) { event(answer(call), id: 'event-3') })
        started = monotonic_now

        expect(client.request('tools/call', { name: 'slow' })).to eq('content' => [])
        expect(monotonic_now - started).to be >= 0.2
        expect(a_request(:get, url).with(headers: { 'Last-Event-ID' => 'event-2' })).to have_been_made.once
      end

      it 'gives up on a stream without event IDs' do
        stub_method('tools/call', headers: events, body: event(progress))

        expect { client.request('tools/call', { name: 'slow' }) }.to raise_error(RubyLLM::MCP::Error, /did not answer/)
        expect(a_request(:get, url)).not_to have_been_made
      end

      it 'gives up after a few resumptions' do
        stub_method('tools/call', headers: events, body: event(id: 'event-1', retry_after: 0))
        stub_request(:get, url).to_return(headers: events, body: event(id: 'event-2', retry_after: 0))

        expect { client.request('tools/call', { name: 'slow' }) }.to raise_error(RubyLLM::MCP::Error, /did not answer/)
        expect(a_request(:get, url)).to have_been_made.times(3)
      end

      it 'gives up rather than wait longer than the timeout' do
        stub_method('tools/call', headers: events, body: event(id: 'event-1', retry_after: 3_600_000))

        expect { client.request('tools/call', { name: 'slow' }) }.to raise_error(RubyLLM::MCP::Error, /did not answer/)
        expect(a_request(:get, url)).not_to have_been_made
      end

      it 'stops waiting when the chat is cancelled' do
        stub_method('tools/call', headers: events, body: event(id: 'event-1', retry_after: 60_000))
        stub_method('notifications/cancelled', status: 202, body: '')
        client.server
        started = monotonic_now
        cancel = -> { raise RubyLLM::CancelledError if monotonic_now - started > 0.2 }

        expect { RubyLLM::Support::Cancellation.watch(cancel) { client.request('tools/call', { name: 'slow' }) } }
          .to raise_error(RubyLLM::CancelledError)
        expect(monotonic_now - started).to be < 5
        expect(a_request(:get, url)).not_to have_been_made
      end
    end
  end

  describe 'over a real connection' do
    around do |example|
      WebMock.disable!
      example.run
    ensure
      WebMock.enable!
    end

    def serve(responses)
      server = TCPServer.new('127.0.0.1', 0)
      sockets = []
      worker = Thread.new do
        responses.each do |respond|
          socket = server.accept
          sockets << socket
          head = socket.gets("\r\n\r\n")
          respond.call(socket, JSON.parse(socket.read(head[/^content-length: (\d+)/i, 1].to_i)))
        end
      end
      yield RubyLLM::MCP::Client.new(described_class.new("http://127.0.0.1:#{server.addr[1]}/mcp", timeout: 3))
    ensure
      worker&.kill
      sockets&.each(&:close)
      server&.close
    end

    def discovered(socket, request)
      body = { jsonrpc: '2.0', id: request['id'], result: discover_result }.to_json
      socket.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n" \
                   "Connection: close\r\n\r\n#{body}")
      socket.close
    end

    def open_stream(socket, *events)
      socket.write("HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nTransfer-Encoding: chunked\r\n\r\n")
      events.each { |data| socket.write("#{data.bytesize.to_s(16)}\r\n#{data}\r\n") }
    end

    def answer(request)
      "data: #{{ jsonrpc: '2.0', id: request['id'], result: { content: [] } }.to_json}\n\n"
    end

    it 'returns the answer while the server keeps the stream open' do
      serve([method(:discovered), ->(socket, request) { open_stream(socket, answer(request)) }]) do |client|
        expect(client.request('tools/call', { name: 'slow' })).to eq('content' => [])
      end
    end

    it 'sends the request again when the connection breaks midway' do
      broken = lambda do |socket, _request|
        open_stream(socket, "data: #{{ jsonrpc: '2.0', method: 'notifications/progress', params: {} }.to_json}\n\n")
        socket.close
      end

      serve([method(:discovered), broken, ->(socket, request) { open_stream(socket, answer(request)) }]) do |client|
        expect(client.request('tools/call', { name: 'slow' })).to eq('content' => [])
      end
    end
  end

  describe 'listening over a real connection' do
    let(:changes) { Queue.new }
    let(:mcp) do
      url = server.url
      changes = self.changes
      Class.new(RubyLLM::MCP) do
        url url
        after_change { |change| changes << change }
      end.new
    end

    around do |example|
      WebMock.disable!
      example.run
    ensure
      WebMock.enable!
    end

    before do
      stub_const('RubyLLM::MCP::Listener::RETRY_DELAY', 0.01)
      allow(RubyLLM.logger).to receive(:warn)
    end

    after do
      mcp.close
      server.close
    end

    def next_change
      Timeout.timeout(5) { changes.pop }
    end

    def eventually
      Timeout.timeout(5) do
        loop do
          result = yield
          return result if result

          sleep 0.01
        end
      end
    end

    def modern_server
      MCPStreams::Server.new do |request, reply|
        case request.rpc_method
        when 'server/discover'
          reply.json(result: { supportedVersions: ['2026-07-28'],
                               capabilities: { tools: { listChanged: true }, resources: { subscribe: true } } })
        when 'subscriptions/listen' then yield(request, reply)
        when 'tools/list' then reply.json(result: { tools: [] })
        end
      end
    end

    def legacy_server(events:)
      MCPStreams::Server.new do |request, reply|
        case request.verb == 'GET' ? 'GET' : request.rpc_method
        when 'server/discover' then reply.status(404)
        when 'initialize'
          reply.json(headers: { 'Mcp-Session-Id' => 'session-1' },
                     result: { protocolVersion: '2025-06-18',
                               capabilities: { tools: { listChanged: true }, resources: { subscribe: true } } })
        when 'GET' then events ? reply.stream : reply.status(405)
        when 'resources/subscribe', 'ping' then reply.json(result: {})
        else reply.status(202)
        end
      end
    end

    def subscription_id
      server.requests_for('subscriptions/listen').last.body['id']
    end

    def changed(method, **params)
      meta = { 'io.modelcontextprotocol/subscriptionId' => subscription_id }
      server.push(jsonrpc: '2.0', method:, params: params.merge(_meta: meta))
    end

    context 'with a 2026-07-28 server' do
      let(:server) do
        modern_server do |request, reply|
          reply.stream(jsonrpc: '2.0', method: 'notifications/subscriptions/acknowledged',
                       params: { _meta: { 'io.modelcontextprotocol/subscriptionId' => request.body['id'] },
                                 notifications: request.body.dig('params', 'notifications') })
        end
      end

      it 'subscribes on a stream that stays open, with the standard headers' do
        mcp.listen(resources: ['file:///notes.md'])

        listen = server.requests_for('subscriptions/listen').first
        expect(listen.headers)
          .to include('mcp-method' => 'subscriptions/listen', 'mcp-protocol-version' => '2026-07-28')
        expect(listen.body.dig('params', 'notifications'))
          .to eq('toolsListChanged' => true, 'resourceSubscriptions' => ['file:///notes.md'])

        changed('notifications/resources/updated', uri: 'file:///notes.md')
        expect(next_change).to have_attributes(uri: 'file:///notes.md')
      end

      it 'runs callbacks that call the server while the stream stays open' do
        sizes = changes
        mcp.class.after_change { |change| sizes << tools.size if change == :tools }
        mcp.listen

        changed('notifications/tools/list_changed')

        expect([next_change, next_change]).to eq([:tools, 0])
        expect(server.open_streams).to eq(1)
      end

      it 'ignores the comments a server sends to keep the stream alive' do
        mcp.listen

        server.write_event(': keepalive')
        changed('notifications/tools/list_changed')

        expect(next_change).to eq(:tools)
      end

      it 'closes the stream when the MCP closes' do
        mcp.listen

        mcp.close

        expect(eventually { server.open_streams.zero? }).to be(true)
      end

      it 'subscribes again for the same changes when the connection drops' do
        mcp.listen

        server.drop

        renewed = eventually { server.requests_for('subscriptions/listen')[1] }
        expect(renewed.body.dig('params', 'notifications')).to eq('toolsListChanged' => true)
        expect(RubyLLM.logger).to have_received(:warn).once
        changed('notifications/tools/list_changed')
        expect(next_change).to eq(:tools)
      end

      it 'subscribes again for the same changes when the server ends the subscription' do
        mcp.listen

        server.finish

        renewed = eventually { server.requests_for('subscriptions/listen')[1] }
        expect(renewed.body.dig('params', 'notifications')).to eq('toolsListChanged' => true)
      end
    end

    context 'with a 2026-07-28 server that does not know subscriptions/listen' do
      let(:server) do
        modern_server do |_request, reply|
          reply.json(status: 404, error: { code: -32_601, message: 'Method not found' })
        end
      end

      it 'raises' do
        expect { mcp.listen }.to raise_error(RubyLLM::MCP::Error, 'Method not found')
      end
    end

    context 'with a server that predates 2026-07-28' do
      let(:server) { legacy_server(events: true) }

      it 'subscribes to resources, listens on the session stream, and answers pings' do
        mcp.listen(resources: ['file:///notes.md'])

        expect(server.requests_for('resources/subscribe').map { |request| request.body.dig('params', 'uri') })
          .to eq(['file:///notes.md'])
        eventually { server.open_streams == 1 }
        expect(server.requests.find { |request| request.verb == 'GET' }.headers)
          .to include('mcp-session-id' => 'session-1', 'accept' => 'text/event-stream')

        server.push(jsonrpc: '2.0', id: 'ping-1', method: 'ping')
        server.push(jsonrpc: '2.0', method: 'notifications/resources/updated', params: { uri: 'file:///notes.md' })

        expect(next_change).to have_attributes(uri: 'file:///notes.md')
        pong = eventually { server.requests.find { |request| request.body&.fetch('id', nil) == 'ping-1' } }
        expect(pong.body).to include('result' => {})
        expect(pong.headers).to include('mcp-session-id' => 'session-1')
      end
    end

    context 'with a server that predates 2026-07-28 and ends the session' do
      let(:server) do
        sessions = 0
        MCPStreams::Server.new do |request, reply|
          case request.verb == 'GET' ? 'GET' : request.rpc_method
          when 'server/discover' then reply.status(404)
          when 'initialize'
            sessions += 1
            reply.json(headers: { 'Mcp-Session-Id' => "session-#{sessions}" },
                       result: { protocolVersion: '2025-06-18', capabilities: { resources: { subscribe: true } } })
          when 'GET' then request.headers['mcp-session-id'] == 'session-1' ? reply.status(404) : reply.stream
          when 'resources/subscribe', 'ping' then reply.json(result: {})
          else reply.status(202)
          end
        end
      end

      it 'starts a new session and subscribes again' do
        mcp.listen(resources: ['file:///notes.md'])

        eventually { server.open_streams == 1 }

        expect(server.requests_for('resources/subscribe').map { |request| request.headers['mcp-session-id'] })
          .to eq(%w[session-1 session-2])
      end
    end

    context 'with a server that predates 2026-07-28 and asks the client something mid-call' do
      let(:mcp) { RubyLLM.mcp(url: server.url, timeout: 5) }
      let(:server) do
        asks = self.asks
        MCPStreams::Server.new do |request, reply|
          case request.rpc_method
          when 'server/discover' then reply.status(404)
          when 'initialize'
            reply.json(headers: { 'Mcp-Session-Id' => 'session-1' },
                       result: { protocolVersion: '2025-06-18', capabilities: { tools: {} } })
          when 'tools/list' then reply.json(result: { tools: [{ name: 'deploy', inputSchema: { type: 'object' } }] })
          when 'tools/call'
            reply.stream(*asks.map { |id, method| { jsonrpc: '2.0', id:, method:, params: {} } })
          else reply.status(202)
          end
        end
      end

      def asks
        { 'ping-1' => 'ping', 'roots-1' => 'roots/list', 'sample-1' => 'sampling/createMessage',
          'elicit-1' => 'elicitation/create' }
      end

      def answers
        server.requests.select { |request| request.verb == 'POST' && asks.key?(request.body['id']) }
      end

      it 'answers right away, pings with a result and everything else with method not found' do
        call = Thread.new { mcp.call(:deploy) }

        replies = eventually { answers.size == asks.size && answers }
        call_id = server.requests_for('tools/call').first.body['id']
        server.push(jsonrpc: '2.0', id: call_id, result: { content: [{ type: 'text', text: 'Deployed' }] })

        expect(call.value.text).to eq('Deployed')
        expect(replies.to_h { |request| [request.body['id'], request.body['result'] || request.body['error']] })
          .to eq('ping-1' => {}, 'roots-1' => { 'code' => -32_601, 'message' => 'Method not found' },
                 'sample-1' => { 'code' => -32_601, 'message' => 'Method not found' },
                 'elicit-1' => { 'code' => -32_601, 'message' => 'Method not found' })
        expect(replies.map { |request| request.headers['mcp-session-id'] }.uniq).to eq(['session-1'])
      ensure
        call&.kill
      end
    end

    context 'with a server that predates 2026-07-28 and offers no event stream' do
      let(:server) { legacy_server(events: false) }

      it 'stops listening instead of asking again' do
        mcp.listen

        sleep 0.2

        expect(server.requests.count { |request| request.verb == 'GET' }).to eq(1)
      end
    end
  end

  it 'keeps only the answers of a stream, so one that stays open does not grow' do
    stream = described_class::Stream.new('listen-1') { |_message| nil }
    event = "data: #{{ jsonrpc: '2.0', method: 'notifications/tools/list_changed' }.to_json}\n\n"

    100.times { stream.feed(event) }

    expect(stream.replies).to be_empty
  end

  it 'has no session to end with a 2026-07-28 server' do
    stub_method('server/discover', result: discover_result)
    client.server

    client.close

    expect(a_request(:delete, url)).not_to have_been_made
  end

  it 'uses a result the server sends with an error status' do
    stub_method('server/discover', result: discover_result)
    stub_method('tools/list', status: 403, result: { tools: [{ name: 'search' }] })

    expect(client.request('tools/list')).to eq('tools' => [{ 'name' => 'search' }])
  end

  it 'raises UnauthorizedError when the server wants credentials' do
    stub_method('server/discover', status: 401, body: '')

    expect { client.server }.to raise_error(RubyLLM::UnauthorizedError, 'mcp.example.com requires authorization')
  end

  it 'resolves callable headers on every request' do
    tokens = %w[first second].each
    headers = ->(_verb) { { 'Authorization' => tokens.next } }
    client = RubyLLM::MCP::Client.new(described_class.new(url, headers:))
    stub_method('server/discover', result: discover_result)
    stub_method('tools/list', result: { tools: [] })

    client.request('tools/list')

    expect(a_request(:post, url).with(headers: { 'Authorization' => 'second' })).to have_been_made
  end
end
