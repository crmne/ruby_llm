# frozen_string_literal: true

require 'spec_helper'

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
    client = RubyLLM::MCP::Client.new(described_class.new(url, headers: -> { { 'Authorization' => tokens.next } }))
    stub_method('server/discover', result: discover_result)
    stub_method('tools/list', result: { tools: [] })

    client.request('tools/list')

    expect(a_request(:post, url).with(headers: { 'Authorization' => 'second' })).to have_been_made
  end
end
