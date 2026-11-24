# frozen_string_literal: true

require 'spec_helper'
require_relative '../../support/mcp_stream_server'

RSpec.describe RubyLLM::MCP::EventType do
  let(:mcp) { RubyLLM.mcp(url: server.url, name: 'pager') }
  let(:capabilities) { { extensions: { 'io.modelcontextprotocol/events' => {} } } }
  let(:answers) { {} }
  let(:server) do
    capabilities = self.capabilities
    answers = self.answers
    listed = [incidents, emails, misdeclared]
    MCPStreams::Server.new do |request, reply|
      case request.rpc_method
      when 'server/discover' then reply.json(result: { supportedVersions: ['2026-07-28'], capabilities: })
      when 'events/list'
        page = request.body.dig('params', 'cursor').to_i
        reply.json(result: { events: [listed[page]], nextCursor: (page + 1 if page < 2)&.to_s }.compact)
      else reply.json(**answers.fetch(request.rpc_method))
      end
    end
  end

  def incidents
    { name: 'incident.created', description: 'Fires when an incident is created', delivery: %w[webhook push poll],
      inputSchema: { type: 'object', properties: { severity: { type: 'string' },
                                                   region: { type: 'string', 'x-mcp-header' => 'Region' } } },
      payloadSchema: { type: 'object', properties: { incidentId: { type: 'string' } } } }
  end

  def emails
    { name: 'email.received', delivery: ['poll'] }
  end

  def misdeclared
    { name: 'broken', delivery: ['poll'],
      inputSchema: { type: 'object', properties: { region: { type: 'object', 'x-mcp-header' => 'Region' } } } }
  end

  around do |example|
    WebMock.disable!
    example.run
  ensure
    WebMock.enable!
  end

  before { allow(RubyLLM.logger).to receive(:warn) }

  after do
    mcp.close
    server.close
  end

  def sent(method)
    server.requests_for(method).last
  end

  describe 'listing' do
    it 'lists every page of the event types a server announces' do
      expect(mcp.event_types.map(&:name)).to eq(%w[incident.created email.received])
      expect(mcp.event_types.first)
        .to have_attributes(description: 'Fires when an incident is created', delivery: %i[webhook push poll],
                            parameters_schema: include('type' => 'object'),
                            payload_schema: include('properties' => { 'incidentId' => { 'type' => 'string' } }),
                            arguments: {})
    end

    it 'asks the server once' do
      2.times { mcp.event_types }

      expect(server.requests_for('events/list').size).to eq(3)
    end

    it 'leaves out an event type whose headers are invalid, with a warning' do
      mcp.event_types

      expect(RubyLLM.logger).to have_received(:warn) do |&message|
        expect(message.call).to eq('Ignoring MCP event broken: it declares invalid x-mcp-header values')
      end
    end

    it 'inspects as one short line' do
      expect(mcp.event_type('email.received', from: '*@example.com').inspect)
        .to eq('#<RubyLLM::MCP::EventType name: "email.received", delivery: [:poll], ' \
               'arguments: {from: "*@example.com"}>')
    end

    context 'with a server that declares events as a capability of their own' do
      let(:capabilities) { { tools: {}, events: {} } }

      it 'lists its event types' do
        expect(mcp.event_types.size).to eq(2)
      end
    end

    context 'with a server without events' do
      let(:capabilities) { { tools: {} } }

      it 'lists none, without asking' do
        expect(mcp.event_types).to eq([])
        expect(server.requests_for('events/list')).to be_empty
      end

      it 'raises for an event type' do
        expect { mcp.event_type('incident.created') }
          .to raise_error(RubyLLM::MCP::Error, 'pager does not announce incident.created events')
      end
    end
  end

  describe '#poll' do
    let(:answers) do
      { 'events/poll' => { result: { events: [{ eventId: 'evt_001', name: 'incident.created',
                                                timestamp: '2026-02-19T15:30:00Z', data: { incidentId: 'INC-1' } }],
                                     cursor: 'history_99842', truncated: true, hasMore: true, nextPollMs: 30_000 } } }
    end

    it 'starts from now without a cursor, with the headers the server routes on' do
      mcp.event_type('incident.created', severity: 'P1', region: 'us-west1').poll

      expect(sent('events/poll').body['params'])
        .to include('name' => 'incident.created', 'arguments' => { 'severity' => 'P1', 'region' => 'us-west1' },
                    'cursor' => nil)
      expect(sent('events/poll').body['params'].keys).not_to include('maxAgeMs', 'maxEvents')
      expect(sent('events/poll').headers)
        .to include('mcp-method' => 'events/poll', 'mcp-name' => 'incident.created', 'mcp-param-region' => 'us-west1')
    end

    it 'polls from a cursor, within an age and a limit' do
      mcp.event_type('incident.created').poll(cursor: 'history_1', max_age: 300, limit: 50)

      expect(sent('events/poll').body['params'])
        .to include('cursor' => 'history_1', 'maxAgeMs' => 300_000, 'maxEvents' => 50, 'arguments' => {})
    end

    it 'returns the events and where to poll from next' do
      page = mcp.event_type('incident.created').poll

      expect(page).to have_attributes(cursor: 'history_99842', more?: true, truncated?: true, poll_interval: 30.0,
                                      empty?: false)
      expect(page.map(&:id)).to eq(['evt_001'])
      expect(page.first).to have_attributes(name: 'incident.created', timestamp: Time.utc(2026, 2, 19, 15, 30),
                                            data: { 'incidentId' => 'INC-1' }, cursor: nil)
      expect(page.inspect)
        .to eq('#<RubyLLM::MCP::EventPage events: 1, cursor: "history_99842", more: true, truncated: true>')
      expect(page.first.inspect)
        .to eq('#<RubyLLM::MCP::Event id: "evt_001", name: "incident.created", timestamp: "2026-02-19T15:30:00Z">')
    end

    context 'when nothing happened' do
      let(:answers) { { 'events/poll' => { result: { events: [], cursor: nil } } } }

      it 'returns an empty page' do
        expect(mcp.event_type('incident.created').poll)
          .to have_attributes(empty?: true, cursor: nil, more?: false, truncated?: false, poll_interval: nil)
      end
    end

    context 'when the server refuses' do
      let(:answers) { { 'events/poll' => { error: { code: -32_024, message: 'Forbidden' } } } }

      it 'raises with the code of the server' do
        expect { mcp.event_type('incident.created').poll }
          .to raise_error(RubyLLM::MCP::Error) { |error| expect(error.code).to eq(-32_024) }
      end
    end
  end

  describe '#subscribe' do
    def secret
      "whsec_#{['a signing key of thirty-two bytes'].pack('m0')}"
    end

    def url
      'https://app.example.com/mcp_events'
    end

    let(:answers) do
      { 'events/subscribe' => { result: { id: 'sub_a3f1', refreshBefore: '2026-02-19T16:30:00Z', cursor: 'cursor_1',
                                          truncated: false } } }
    end

    it 'asks the server to post the events to the address' do
      mcp.event_type('incident.created', severity: 'P1').subscribe(url:, secret:)

      params = sent('events/subscribe').body['params']
      expect(params).to eq('name' => 'incident.created', 'arguments' => { 'severity' => 'P1' }, 'cursor' => nil,
                           'delivery' => { 'mode' => 'webhook', 'url' => url, 'secret' => secret },
                           '_meta' => params['_meta'])
      expect(sent('events/subscribe').headers).to include('mcp-name' => 'incident.created')
    end

    it 'subscribes from a cursor, within an age, for a while' do
      mcp.event_type('incident.created').subscribe(url:, secret:, cursor: 'cursor_0', max_age: 300, ttl: 3600)

      expect(sent('events/subscribe').body['params'])
        .to include('cursor' => 'cursor_0', 'maxAgeMs' => 300_000, 'ttlMs' => 3_600_000)
    end

    it 'returns the subscription' do
      subscription = mcp.event_type('incident.created').subscribe(url:, secret:)

      expect(subscription).to have_attributes(id: 'sub_a3f1', refresh_before: Time.utc(2026, 2, 19, 16, 30),
                                              cursor: 'cursor_1', truncated?: false, last_error: nil)
      expect(subscription.inspect)
        .to eq('#<RubyLLM::MCP::EventSubscription id: "sub_a3f1", refresh_before: "2026-02-19T16:30:00Z">')
    end

    context 'when asked never to expire' do
      let(:answers) do
        { 'events/subscribe' => { result: { id: 'sub_a3f1', refreshBefore: nil, cursor: nil, truncated: true,
                                            deliveryStatus: { active: false, lastError: 'http_4xx' } } } }
      end

      it 'asks for no expiry and reads what the server says about its deliveries' do
        subscription = mcp.event_type('incident.created').subscribe(url:, secret:, ttl: Float::INFINITY)

        expect(sent('events/subscribe').body['params']).to include('ttlMs' => nil)
        expect(subscription).to have_attributes(refresh_before: nil, truncated?: true, last_error: 'http_4xx')
      end
    end
  end

  describe '#unsubscribe' do
    let(:answers) { { 'events/unsubscribe' => { result: {} } } }

    it 'ends the subscription that posts to the address' do
      incidents = mcp.event_type('incident.created', severity: 'P1')

      expect(incidents.unsubscribe(url: 'https://app.example.com/mcp_events')).to be(incidents)

      params = sent('events/unsubscribe').body['params']
      expect(params.except('_meta'))
        .to eq('name' => 'incident.created', 'arguments' => { 'severity' => 'P1' },
               'delivery' => { 'mode' => 'webhook', 'url' => 'https://app.example.com/mcp_events' })
    end
  end

  it 'declares the extension by name' do
    declared = Class.new(RubyLLM::MCP) { extension :events }

    expect(declared.extensions).to eq('io.modelcontextprotocol/events' => {})
  end
end
