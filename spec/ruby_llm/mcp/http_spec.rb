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
