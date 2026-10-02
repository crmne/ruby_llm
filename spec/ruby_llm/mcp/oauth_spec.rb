# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::MCP::OAuth do
  let(:server_url) { 'https://mcp.example.com/mcp' }
  let(:authorization_server) do
    {
      issuer: 'https://auth.example.com', authorization_endpoint: 'https://auth.example.com/authorize',
      token_endpoint: 'https://auth.example.com/token', registration_endpoint: 'https://auth.example.com/register',
      code_challenge_methods_supported: ['S256'], authorization_response_iss_parameter_supported: true
    }
  end
  let(:linear_class) do
    url = server_url
    Class.new(RubyLLM::MCP) do
      url url
      inputs :user
      oauth owner: :user
    end
  end
  let(:linear) { linear_class.new(user: 'ada') }
  let(:redirect_uri) { 'https://app.example.com/mcp/callback' }

  around do |example|
    previous = RubyLLM.config.mcp_credential_store
    RubyLLM.config.mcp_credential_store = described_class::MemoryStore.new
    example.run
  ensure
    RubyLLM.config.mcp_credential_store = previous
  end

  before do
    stub_request(:post, server_url).to_return do |request|
      if ['Bearer access-1', 'Bearer access-2'].include?(request.headers['Authorization'])
        message = JSON.parse(request.body)
        result = message['method'] == 'server/discover' ? { supportedVersions: ['2026-07-28'] } : { tools: [] }
        { status: 200, headers: { 'Content-Type' => 'application/json' },
          body: { jsonrpc: '2.0', id: message['id'], result: }.to_json }
      else
        { status: 401, headers: { 'WWW-Authenticate' => challenge } }
      end
    end
    stub_request(:get, 'https://mcp.example.com/.well-known/oauth-protected-resource/mcp')
      .to_return(body: { resource: server_url, authorization_servers: ['https://auth.example.com'] }.to_json)
    stub_request(:get, 'https://auth.example.com/.well-known/oauth-authorization-server')
      .to_return(body: authorization_server.to_json)
    stub_request(:post, 'https://auth.example.com/register').to_return(body: { client_id: 'registered' }.to_json)
    stub_request(:post, 'https://auth.example.com/token').to_return do |request|
      grant = URI.decode_www_form(request.body).to_h['grant_type']
      token = grant == 'refresh_token' ? 'access-2' : 'access-1'
      { body: { access_token: token, refresh_token: 'refresh-1', expires_in: 3600 }.to_json }
    end
  end

  def challenge
    'Bearer resource_metadata="https://mcp.example.com/.well-known/oauth-protected-resource/mcp", scope="issues:read"'
  end

  def callback(url, **overrides)
    params = URI.decode_www_form(URI(url).query).to_h
    { code: 'code-1', state: params['state'], iss: 'https://auth.example.com' }.merge(overrides)
  end

  it 'starts an authorization with PKCE, the resource, and the challenged scope' do
    url = linear.authorization_url(redirect_uri:)
    params = URI.decode_www_form(URI(url).query).to_h

    expect(url).to start_with('https://auth.example.com/authorize?')
    expect(params).to include('client_id' => 'registered', 'code_challenge_method' => 'S256',
                              'resource' => server_url, 'scope' => 'issues:read', 'redirect_uri' => redirect_uri)
    registration = a_request(:post, 'https://auth.example.com/register').with do |request|
      JSON.parse(request.body).values_at('application_type', 'token_endpoint_auth_method') == %w[web none]
    end
    expect(registration).to have_been_made
  end

  it 'registers for the scopes it requests, and again when it needs more' do
    linear.authorization_url(redirect_uri:)
    url = linear_class.new(user: 'ada').authorization_url(redirect_uri:)
    write_scope = server_url
    writer = Class.new(RubyLLM::MCP) do
      url write_scope
      inputs :user
      oauth owner: :user, scopes: ['issues:write']
    end
    writer.new(user: 'bob').authorization_url(redirect_uri:)

    scopes = []
    expect(a_request(:post, 'https://auth.example.com/register').with do |request|
      scopes << JSON.parse(request.body)['scope']
    end).to have_been_made.twice
    expect(scopes).to eq(['issues:read', 'issues:write issues:read'])
    expect(URI.decode_www_form(URI(url).query).to_h['client_id']).to eq('registered')
  end

  it 'exchanges the code and uses the token' do
    linear.authorize(callback(linear.authorization_url(redirect_uri:)))

    expect(linear).to be_authorized
    expect(linear.tools).to eq([])
    exchange = a_request(:post, 'https://auth.example.com/token').with do |request|
      form = URI.decode_www_form(request.body).to_h
      form.values_at('grant_type', 'resource') == ['authorization_code', server_url] && form['code_verifier']
    end
    expect(exchange).to have_been_made
  end

  it 'sends the server and OAuth requests through the connection of its context' do
    requests = []
    adapter = Class.new(Faraday::Adapter::NetHttp) do
      define_method(:call) do |env|
        requests << "#{env.method.upcase} #{env.url}"
        super(env)
      end
    end
    linear = linear_class.new(user: 'ada', context: RubyLLM.context { |config| config.faraday_adapter = adapter })

    linear.authorize(callback(linear.authorization_url(redirect_uri:)))
    linear.tools

    expect(requests).to include('GET https://auth.example.com/.well-known/oauth-authorization-server',
                                'POST https://auth.example.com/register', 'POST https://auth.example.com/token',
                                "POST #{server_url}")
  end

  it 'keeps credentials per owner' do
    linear.authorize(callback(linear.authorization_url(redirect_uri:)))

    expect(linear_class.new(user: 'grace')).not_to be_authorized
  end

  it 'refreshes an expired token when the server rejects it' do
    linear.authorize(callback(linear.authorization_url(redirect_uri:)))
    store = RubyLLM.config.mcp_credential_store
    key = "ada@#{server_url}"
    store.write(key, store.read(key).merge('access_token' => 'stale'))

    expect(linear_class.new(user: 'ada').tools).to eq([])
    expect(store.read(key)['access_token']).to eq('access-2')
  end

  describe 'refreshing a rotating token' do
    def store = RubyLLM.config.mcp_credential_store
    def key = "ada@#{server_url}"

    def rotating_token_endpoint
      used = Set.new
      stub_request(:post, 'https://auth.example.com/token').to_return do |request|
        reused = !used.add?(URI.decode_www_form(request.body).to_h['refresh_token'])
        sleep 0.2
        next { status: 400, body: { error: 'invalid_grant' }.to_json } if reused

        { body: { access_token: 'access-2', refresh_token: 'refresh-2', expires_in: 3600 }.to_json }
      end
    end

    def refreshes
      a_request(:post, 'https://auth.example.com/token').with { |request| request.body.include?('refresh_token') }
    end

    before { linear.authorize(callback(linear.authorization_url(redirect_uri:))) }

    it 'refreshes once when threads refresh together' do
      store.write(key, store.read(key).merge('expires_at' => 0))
      rotating_token_endpoint

      tokens = Array.new(2) { Thread.new { linear_class.new(user: 'ada').send(:oauth).access_token } }.map(&:value)

      expect(tokens).to eq(%w[access-2 access-2])
      expect(refreshes).to have_been_made.once
      expect(store.read(key)['refresh_token']).to eq('refresh-2')
    end

    it 'uses the token another worker refreshed since the server rejected its own' do
      oauth = linear_class.new(user: 'ada').send(:oauth)
      oauth.access_token
      store.write(key, store.read(key).merge('access_token' => 'access-2', 'refresh_token' => 'refresh-2'))

      expect(oauth.refresh).to be(true)
      expect(oauth.access_token).to eq('access-2')
      expect(refreshes).not_to have_been_made
    end
  end

  it 'refuses a callback with the wrong state' do
    url = linear.authorization_url(redirect_uri:)

    expect { linear.authorize(callback(url, state: 'forged')) }
      .to raise_error(RubyLLM::MCP::Error, 'The authorization state does not match')
  end

  it 'refuses a callback from another issuer, or none when one is required' do
    url = linear.authorization_url(redirect_uri:)

    expect { linear.authorize(callback(url, iss: 'https://evil.example.com')) }
      .to raise_error(RubyLLM::MCP::Error, /wrong issuer/)
    expect { linear.authorize(callback(url, iss: nil)) }.to raise_error(RubyLLM::MCP::Error, /did not identify/)
  end

  [%w[https://auth.example.com/ https://auth.example.com], %w[https://auth.example.com https://auth.example.com/]]
    .each do |listed, published|
    it "accepts issuer #{published} for authorization server #{listed}" do
      stub_request(:get, 'https://mcp.example.com/.well-known/oauth-protected-resource/mcp')
        .to_return(body: { resource: server_url, authorization_servers: [listed] }.to_json)
      stub_request(:get, 'https://auth.example.com/.well-known/oauth-authorization-server')
        .to_return(body: authorization_server.merge(issuer: published).to_json)

      url = linear.authorization_url(redirect_uri:)
      linear.authorize(callback(url, iss: published))

      expect(linear).to be_authorized
    end
  end

  it 'compares the iss parameter exactly, without normalizing a trailing slash' do
    url = linear.authorization_url(redirect_uri:)

    expect { linear.authorize(callback(url, iss: 'https://auth.example.com/')) }
      .to raise_error(RubyLLM::MCP::Error, /wrong issuer/)
  end

  context 'when the listed issuer serves metadata naming another issuer' do
    before do
      stub_request(:get, 'https://mcp.example.com/.well-known/oauth-protected-resource/mcp')
        .to_return(body: { resource: server_url, authorization_servers: ['https://api.example.com'] }.to_json)
      stub_request(:get, 'https://api.example.com/.well-known/oauth-authorization-server')
        .to_return(body: authorization_server.to_json)
    end

    it 'follows it once to metadata the named issuer publishes about itself' do
      url = linear.authorization_url(redirect_uri:)
      linear.authorize(callback(url, iss: 'https://auth.example.com'))

      expect(url).to start_with('https://auth.example.com/authorize?')
      expect(linear).to be_authorized
    end

    it 'compares iss with the issuer it confirmed' do
      url = linear.authorization_url(redirect_uri:)

      expect { linear.authorize(callback(url, iss: 'https://api.example.com')) }
        .to raise_error(RubyLLM::MCP::Error, /wrong issuer/)
    end

    it 'refuses when the named issuer does not name itself' do
      stub_request(:get, 'https://auth.example.com/.well-known/oauth-authorization-server')
        .to_return(body: authorization_server.merge(issuer: 'https://other.example.com').to_json)

      expect { linear.authorization_url(redirect_uri:) }.to raise_error(RubyLLM::MCP::Error, /different issuer/)
    end

    it 'refuses when the named issuer publishes no metadata' do
      stub_request(:get, %r{\Ahttps://auth\.example\.com/\.well-known/}).to_return(status: 404)

      expect { linear.authorization_url(redirect_uri:) }.to raise_error(RubyLLM::MCP::Error, /publishes no/)
    end
  end

  it 'uses a pre-registered client with its secret' do
    url = server_url
    slack = Class.new(RubyLLM::MCP) do
      url url
      oauth client_id: 'slack-app', client_secret: 'shh'
    end.new

    slack.authorize(callback(slack.authorization_url(redirect_uri:)))

    expect(a_request(:post, 'https://auth.example.com/register')).not_to have_been_made
    expect(a_request(:post, 'https://auth.example.com/token')
      .with(headers: { 'Authorization' => "Basic #{Base64.strict_encode64('slack-app:shh')}" })).to have_been_made
  end

  describe 'a pre-registered client' do
    def pre_registered(client_id)
      url = server_url
      Class.new(RubyLLM::MCP) do
        url url
        oauth client_id:, client_secret: 'shh'
      end.new
    end

    def moved_to(issuer)
      stub_request(:get, 'https://mcp.example.com/.well-known/oauth-protected-resource/mcp')
        .to_return(body: { resource: server_url, authorization_servers: [issuer] }.to_json)
      stub_request(:get, "#{issuer}/.well-known/oauth-authorization-server")
        .to_return(body: authorization_server.merge(issuer:, authorization_endpoint: "#{issuer}/authorize",
                                                    token_endpoint: "#{issuer}/token").to_json)
    end

    it 'stays with the authorization server it was first used with' do
      slack = pre_registered('slack-app')
      slack.authorize(callback(slack.authorization_url(redirect_uri:)))
      moved_to('https://elsewhere.example.com')

      expect { pre_registered('slack-app').authorization_url(redirect_uri:) }
        .to raise_error(RubyLLM::MCP::Error, 'slack-app is registered with https://auth.example.com, ' \
                                             "but #{server_url} now uses https://elsewhere.example.com")
      expect(a_request(:post, 'https://elsewhere.example.com/token')).not_to have_been_made
    end

    it 'binds another client to the authorization server it is used with' do
      pre_registered('slack-app').authorization_url(redirect_uri:)
      moved_to('https://elsewhere.example.com')

      url = pre_registered('elsewhere-app').authorization_url(redirect_uri:)

      expect(url).to start_with('https://elsewhere.example.com/authorize?')
    end
  end

  it 'refuses authorization servers without PKCE' do
    stub_request(:get, 'https://auth.example.com/.well-known/oauth-authorization-server')
      .to_return(body: authorization_server.except(:code_challenge_methods_supported).to_json)

    expect { linear.authorization_url(redirect_uri:) }.to raise_error(RubyLLM::MCP::Error, /PKCE/)
  end

  it 'refuses metadata for another resource' do
    stub_request(:get, 'https://mcp.example.com/.well-known/oauth-protected-resource/mcp')
      .to_return(body: { resource: 'https://other.example.com/mcp',
                         authorization_servers: ['https://auth.example.com'] }.to_json)

    expect { linear.authorization_url(redirect_uri:) }.to raise_error(RubyLLM::MCP::Error, /another resource/)
  end

  ['https://mcp.example.com.attacker.io/mcp', 'https://mcp.example.com:8443/mcp'].each do |impostor|
    it "refuses a server at #{impostor} claiming another server's resource" do
      metadata = URI.join(impostor, '/.well-known/oauth-protected-resource/mcp').to_s
      stub_request(:post, impostor)
        .to_return(status: 401, headers: { 'WWW-Authenticate' => "Bearer resource_metadata=\"#{metadata}\"" })
      stub_request(:get, metadata)
        .to_return(body: { resource: server_url, authorization_servers: ['https://auth.example.com'] }.to_json)
      mcp = Class.new(RubyLLM::MCP) do
        url impostor
        oauth
      end.new

      expect { mcp.authorization_url(redirect_uri:) }.to raise_error(RubyLLM::MCP::Error, /another resource/)
    end
  end

  it 'reads WWW-Authenticate challenges' do
    expect(described_class.challenge('Bearer error="insufficient_scope", scope="a b", resource_metadata="https://x.test/m?a=1"'))
      .to eq(error: 'insufficient_scope', scope: 'a b', resource_metadata: 'https://x.test/m?a=1')
  end

  it 'refuses an authorization endpoint that is not HTTPS' do
    stub_request(:get, 'https://auth.example.com/.well-known/oauth-authorization-server')
      .to_return(body: authorization_server.merge(authorization_endpoint: 'javascript:alert(1)').to_json)

    expect { linear.authorization_url(redirect_uri:) }.to raise_error(RubyLLM::MCP::Error, /HTTPS/)
  end

  it 'needs the declared owner' do
    expect { linear_class.new.authorized? }.to raise_error(ArgumentError, /needs an owner/)
  end

  it 'keeps refreshing with the token endpoint that issued the token' do
    linear.authorize(callback(linear.authorization_url(redirect_uri:)))
    stub_request(:get, 'https://auth.example.com/.well-known/oauth-authorization-server')
      .to_return(body: authorization_server.merge(token_endpoint: 'https://evil.example.com/token').to_json)
    linear.authorization_url(redirect_uri:)

    linear_class.new(user: 'ada').send(:oauth).refresh

    expect(a_request(:post, 'https://evil.example.com/token')).not_to have_been_made
  end

  it 'ignores metadata URLs on other hosts' do
    stub_request(:post, server_url).to_return(
      status: 401, headers: { 'WWW-Authenticate' => 'Bearer resource_metadata="https://internal.example.com/metadata"' }
    )

    linear.authorization_url(redirect_uri:)

    expect(a_request(:get, 'https://internal.example.com/metadata')).not_to have_been_made
    expect(a_request(:get, 'https://mcp.example.com/.well-known/oauth-protected-resource/mcp')).to have_been_made
  end

  it 'asks for challenged scopes along with the ones already granted' do
    linear.authorize(callback(linear.authorization_url(redirect_uri:)))
    stub_request(:post, server_url).to_return(
      status: 403, headers: { 'WWW-Authenticate' => 'Bearer error="insufficient_scope", scope="issues:write"' }
    )
    step_up = linear_class.new(user: 'ada')

    expect { step_up.tools }.to raise_error(RubyLLM::ForbiddenError)
    params = URI.decode_www_form(URI(step_up.authorization_url(redirect_uri:)).query).to_h
    expect(params['scope'].split).to contain_exactly('issues:write', 'issues:read')
  end

  it 'uses the server origin for servers without protected resource metadata' do
    stub_request(:get, 'https://mcp.example.com/.well-known/oauth-protected-resource/mcp').to_return(status: 404)
    stub_request(:get, 'https://mcp.example.com/.well-known/oauth-protected-resource').to_return(status: 404)
    stub_request(:get, 'https://mcp.example.com/.well-known/oauth-authorization-server').to_return(status: 404)
    stub_request(:post, 'https://mcp.example.com/register').to_return(body: { client_id: 'legacy' }.to_json)
    stub_request(:post, server_url).to_return(status: 401)

    url = linear.authorization_url(redirect_uri:)

    expect(url).to start_with('https://mcp.example.com/authorize?')
    expect(URI.decode_www_form(URI(url).query).to_h['client_id']).to eq('legacy')
  end

  it 'adds challenged scopes to configured ones' do
    url = server_url
    scoped = Class.new(RubyLLM::MCP) do
      url url
      inputs :user
      oauth owner: :user, scopes: %w[issues:read]
    end.new(user: 'ada')
    scoped.authorize(callback(scoped.authorization_url(redirect_uri:)))
    stub_request(:post, server_url).to_return(
      status: 403, headers: { 'WWW-Authenticate' => 'Bearer error="insufficient_scope", scope="issues:write"' }
    )

    expect { scoped.tools }.to raise_error(RubyLLM::ForbiddenError)
    params = URI.decode_www_form(URI(scoped.authorization_url(redirect_uri:)).query).to_h
    expect(params['scope'].split).to contain_exactly('issues:read', 'issues:write')
  end

  it 'refuses a legacy authorization server without PKCE' do
    stub_request(:get, 'https://mcp.example.com/.well-known/oauth-protected-resource/mcp').to_return(status: 404)
    stub_request(:get, 'https://mcp.example.com/.well-known/oauth-protected-resource').to_return(status: 404)
    stub_request(:get, 'https://mcp.example.com/.well-known/oauth-authorization-server')
      .to_return(body: { issuer: 'https://mcp.example.com', authorization_endpoint: 'https://mcp.example.com/authorize',
                         token_endpoint: 'https://mcp.example.com/token' }.to_json)
    stub_request(:post, server_url).to_return(status: 401)

    expect { linear.authorization_url(redirect_uri:) }.to raise_error(RubyLLM::MCP::Error, /PKCE/)
  end

  it 'refreshes once when the server keeps rejecting the token' do
    linear.authorize(callback(linear.authorization_url(redirect_uri:)))
    stub_request(:post, server_url).to_return(status: 401)

    expect { linear_class.new(user: 'ada').tools }.to raise_error(RubyLLM::UnauthorizedError)
    refreshes = a_request(:post, 'https://auth.example.com/token').with { |request| request.body.include?('refresh_token') }
    expect(refreshes).to have_been_made.once
  end

  describe 'registrations the authorization server forgets' do
    def store = RubyLLM.config.mcp_credential_store
    def key = "ada@#{server_url}"

    def forgotten_client
      stub_request(:post, 'https://auth.example.com/token')
        .to_return(status: 401, body: { error: 'invalid_client', error_description: 'Unknown client' }.to_json)
    end

    def registers_as(client)
      stub_request(:post, 'https://auth.example.com/register').to_return(body: client.to_json)
    end

    def client_id_in(url)
      URI.decode_www_form(URI(url).query).to_h['client_id']
    end

    it 'registers again after a refresh finds the client gone' do
      linear.authorize(callback(linear.authorization_url(redirect_uri:)))
      store.write(key, store.read(key).merge('access_token' => 'stale'))
      forgotten_client
      registers_as(client_id: 'registered-again')

      expect { linear_class.new(user: 'ada').tools }.to raise_error(RubyLLM::UnauthorizedError)
      expect(client_id_in(linear_class.new(user: 'ada').authorization_url(redirect_uri:))).to eq('registered-again')
    end

    it 'registers again after a code exchange finds the client gone' do
      url = linear.authorization_url(redirect_uri:)
      forgotten_client
      registers_as(client_id: 'registered-again')

      expect { linear.authorize(callback(url)) }.to raise_error(RubyLLM::MCP::Error, /Unknown client/) do |error|
        expect(error.data).to include('error' => 'invalid_client')
      end
      expect(client_id_in(linear.authorization_url(redirect_uri:))).to eq('registered-again')
    end

    it 'keeps a registration made since' do
      linear.authorize(callback(linear.authorization_url(redirect_uri:)))
      registration = "client:https://auth.example.com #{redirect_uri}"
      store.write(registration, { 'client_id' => 'newer' }, owner: nil)
      store.write(key, store.read(key).merge('access_token' => 'stale'))
      forgotten_client

      expect { linear_class.new(user: 'ada').tools }.to raise_error(RubyLLM::UnauthorizedError)
      expect(store.read(registration)).to eq('client_id' => 'newer')
    end

    it 'drops the secret of the registration it replaces' do
      registers_as(client_id: 'registered', client_secret: 'old-secret')
      linear.authorize(callback(linear.authorization_url(redirect_uri:)))
      store.write(key, store.read(key).merge('access_token' => 'stale'))
      forgotten_client
      expect { linear_class.new(user: 'ada').tools }.to raise_error(RubyLLM::UnauthorizedError)
      registers_as(client_id: 'registered-again')
      stub_request(:post, 'https://auth.example.com/token')
        .to_return(body: { access_token: 'access-1', refresh_token: 'refresh-1', expires_in: 3600 }.to_json)
      again = linear_class.new(user: 'ada')

      again.authorize(callback(again.authorization_url(redirect_uri:)))

      expect(store.read(key)).to include('client_id' => 'registered-again')
      expect(store.read(key)).not_to have_key('client_secret')
    end
  end

  it 'forgets credentials' do
    linear.authorize(callback(linear.authorization_url(redirect_uri:)))

    expect(linear_class.new(user: 'ada').deauthorize).not_to be_authorized
  end
end
