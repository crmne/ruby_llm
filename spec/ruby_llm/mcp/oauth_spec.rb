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

  def moved_to(issuer)
    stub_request(:get, 'https://mcp.example.com/.well-known/oauth-protected-resource/mcp')
      .to_return(body: { resource: server_url, authorization_servers: [issuer] }.to_json)
    stub_request(:get, "#{issuer}/.well-known/oauth-authorization-server")
      .to_return(body: authorization_server.merge(issuer:, authorization_endpoint: "#{issuer}/authorize",
                                                  token_endpoint: "#{issuer}/token").to_json)
  end

  def token_form
    form = nil
    expect(a_request(:post, 'https://auth.example.com/token').with do |request|
      form = URI.decode_www_form(request.body).to_h
    end).to have_been_made.once
    form
  end

  def declared_extensions
    declared = []
    expect(a_request(:post, server_url).with do |request|
      declared << JSON.parse(request.body).dig('params', '_meta', 'io.modelcontextprotocol/clientCapabilities',
                                               'extensions')
    end).to have_been_made.at_least_once
    declared.uniq
  end

  def verified(jwt, key)
    input, signature = jwt.rpartition('.').values_at(0, 2)
    signature = Base64.urlsafe_decode64(signature)
    if key.is_a?(OpenSSL::PKey::EC)
      signature = OpenSSL::ASN1::Sequence(signature.unpack('a32a32').map do |half|
        OpenSSL::ASN1::Integer(OpenSSL::BN.new(half, 2))
      end).to_der
    end
    raise 'The signature does not verify' unless key.verify('SHA256', signature, input)

    input.split('.').map { |part| JSON.parse(Base64.urlsafe_decode64(part)) }
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

  it 'declares no authorization extension for apps that users authorize' do
    linear.authorize(callback(linear.authorization_url(redirect_uri:)))

    linear_class.new(user: 'ada').tools

    expect(declared_extensions).to eq([nil])
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
      .to eq('bearer' => { error: 'insufficient_scope', scope: 'a b', resource_metadata: 'https://x.test/m?a=1' })
  end

  it 'reads every challenge of a WWW-Authenticate header' do
    header = 'Bearer realm="a, \"b\"", DPoP algs="ES256 PS256", error=use_dpop_nonce, Basic'

    expect(described_class.challenge(header)).to eq('bearer' => { realm: 'a, "b"' },
                                                    'dpop' => { algs: 'ES256 PS256', error: 'use_dpop_nonce' },
                                                    'basic' => {})
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

  describe 'the client credentials grant' do
    def reports(**credentials)
      url = server_url
      Class.new(RubyLLM::MCP) do
        url url
        oauth grant: :client_credentials, client_id: 'reports', **credentials
      end.new
    end

    it 'requests a token when the server asks for one, authenticating with the secret' do
      expect(reports(client_secret: 'shh').tools).to eq([])

      expect(token_form).to include('grant_type' => 'client_credentials', 'resource' => server_url,
                                    'scope' => 'issues:read')
      expect(a_request(:post, 'https://auth.example.com/token')
        .with(headers: { 'Authorization' => "Basic #{Base64.strict_encode64('reports:shh')}" })).to have_been_made
      expect(a_request(:post, 'https://auth.example.com/register')).not_to have_been_made
    end

    it 'form-encodes the client credentials before sending them as Basic authentication' do
      reports(client_secret: 'p:ss%word').tools

      expect(a_request(:post, 'https://auth.example.com/token')
        .with(headers: { 'Authorization' => "Basic #{Base64.strict_encode64('reports:p%3Ass%25word')}" }))
        .to have_been_made
    end

    it 'declares the client credentials extension with every request' do
      reports(client_secret: 'shh').tools

      expect(declared_extensions).to eq([{ 'io.modelcontextprotocol/oauth-client-credentials' => {} }])
    end

    it 'signs an assertion for the issuer with a private key instead of a secret' do
      key = OpenSSL::PKey::EC.generate('prime256v1')

      reports(private_key: key.private_to_pem).tools

      form = token_form
      header, claims = verified(form['client_assertion'], key)
      expect(form).to include('client_assertion_type' => 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer')
      expect(form).not_to include('client_id', 'client_secret')
      expect(header).to eq('typ' => 'client-authentication+jwt', 'alg' => 'ES256')
      expect(claims).to include('iss' => 'reports', 'sub' => 'reports', 'aud' => 'https://auth.example.com')
      expect(claims['exp'] - claims['iat']).to eq(60)
    end

    it 'signs with an RSA key in an algorithm the authorization server accepts' do
      key = OpenSSL::PKey::RSA.generate(2048)
      stub_request(:get, 'https://auth.example.com/.well-known/oauth-authorization-server').to_return(
        body: authorization_server.merge(token_endpoint_auth_signing_alg_values_supported: %w[RS256 ES256]).to_json
      )

      reports(private_key: key).tools

      expect(verified(token_form['client_assertion'], key).first).to include('alg' => 'RS256')
    end

    it 'requests a new token before the old one expires' do
      reports(client_secret: 'shh').tools
      store = RubyLLM.config.mcp_credential_store
      store.write("@#{server_url}", store.read("@#{server_url}").merge('expires_at' => 0))

      reports(client_secret: 'shh').tools

      grants = a_request(:post, 'https://auth.example.com/token')
               .with(body: hash_including('grant_type' => 'client_credentials'))
      expect(grants).to have_been_made.twice
    end

    it "raises the authorization server's reason after asking once" do
      stub_request(:post, 'https://auth.example.com/token')
        .to_return(status: 401, body: { error: 'invalid_client', error_description: 'Unknown client' }.to_json)

      expect { reports(client_secret: 'wrong').tools }
        .to raise_error(RubyLLM::UnauthorizedError, 'auth.example.com refused the request: Unknown client')
      expect(a_request(:post, 'https://auth.example.com/token')).to have_been_made.once
    end

    it 'has no authorization for a user to complete' do
      expect { reports(client_secret: 'shh').authorization_url(redirect_uri:) }
        .to raise_error(RubyLLM::ConfigurationError, 'The client_credentials grant needs no authorization')
    end

    it 'signs the code exchange of an app that users authorize' do
      key = OpenSSL::PKey::EC.generate('prime256v1')
      url = server_url
      slack = Class.new(RubyLLM::MCP) do
        url url
        oauth client_id: 'slack-app', private_key: key
      end.new

      slack.authorize(callback(slack.authorization_url(redirect_uri:)))

      form = token_form
      expect(form).to include('grant_type' => 'authorization_code')
      expect(verified(form['client_assertion'], key).last).to include('iss' => 'slack-app', 'sub' => 'slack-app')
    end
  end

  describe 'the JWT bearer grant' do
    def workload(assertion)
      url = server_url
      Class.new(RubyLLM::MCP) do
        url url
        oauth assertion:
      end
    end

    it "presents the workload's assertion when the server asks for a token" do
      expect(workload('workload-jwt').new.tools).to eq([])

      expect(token_form).to eq('grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                               'assertion' => 'workload-jwt', 'resource' => server_url, 'scope' => 'issues:read')
      expect(a_request(:post, 'https://auth.example.com/token').with(headers: { 'Authorization' => /.+/ }))
        .not_to have_been_made
    end

    it 'reads the assertion again for every token' do
      assertions = []
      stub_request(:post, 'https://auth.example.com/token').to_return do |request|
        assertions << URI.decode_www_form(request.body).to_h['assertion']
        { body: { access_token: 'access-1', expires_in: 3600 }.to_json }
      end
      rotating = %w[first second].each
      platform = workload(-> { rotating.next })
      store = RubyLLM.config.mcp_credential_store

      platform.new.tools
      store.write("@#{server_url}", store.read("@#{server_url}").merge('expires_at' => 0))
      platform.new.tools

      expect(assertions).to eq(%w[first second])
    end

    it 'keeps the assertion from an authorization server the server moves to' do
      workload('workload-jwt').new.tools
      RubyLLM.config.mcp_credential_store.delete("@#{server_url}")
      moved_to('https://elsewhere.example.com')

      expect { workload('workload-jwt').new.tools }
        .to raise_error(RubyLLM::UnauthorizedError, 'The workload is registered with https://auth.example.com, ' \
                                                    "but #{server_url} now uses https://elsewhere.example.com")
      expect(a_request(:post, 'https://elsewhere.example.com/token')).not_to have_been_made
    end
  end

  describe 'enterprise-managed authorization' do
    def wiki_class
      url = server_url
      Class.new(RubyLLM::MCP) do
        url url
        inputs :user
        oauth owner: :user, client_id: 'wiki-app', client_secret: 'wiki-secret',
              identity_provider: { issuer: 'https://idp.example.com', client_id: 'sso-app', client_secret: 'sso-secret',
                                   id_token: -> { "id-token-for-#{user}" } }
      end
    end

    before do
      stub_request(:get, 'https://idp.example.com/.well-known/oauth-authorization-server').to_return(status: 404)
      stub_request(:get, 'https://idp.example.com/.well-known/openid-configuration').to_return(
        body: { issuer: 'https://idp.example.com', token_endpoint: 'https://idp.example.com/token',
                token_endpoint_auth_methods_supported: ['client_secret_post'] }.to_json
      )
      issues_grant('urn:ietf:params:oauth:token-type:id-jag')
    end

    def issues_grant(type)
      stub_request(:post, 'https://idp.example.com/token')
        .to_return(body: { issued_token_type: type, access_token: 'id-jag', token_type: 'N_A' }.to_json)
    end

    it "exchanges the user's ID token for a grant the authorization server accepts" do
      expect(wiki_class.new(user: 'ada').tools).to eq([])

      exchange = nil
      expect(a_request(:post, 'https://idp.example.com/token').with do |request|
        exchange = URI.decode_www_form(request.body).to_h
      end).to have_been_made.once
      expect(exchange).to eq(
        'grant_type' => 'urn:ietf:params:oauth:grant-type:token-exchange',
        'requested_token_type' => 'urn:ietf:params:oauth:token-type:id-jag', 'audience' => 'https://auth.example.com',
        'resource' => server_url, 'scope' => 'issues:read', 'subject_token' => 'id-token-for-ada',
        'subject_token_type' => 'urn:ietf:params:oauth:token-type:id_token', 'client_id' => 'sso-app',
        'client_secret' => 'sso-secret'
      )
      expect(token_form).to eq('grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion' => 'id-jag',
                               'client_id' => 'wiki-app', 'resource' => server_url, 'scope' => 'issues:read')
      expect(a_request(:post, 'https://auth.example.com/token')
        .with(headers: { 'Authorization' => "Basic #{Base64.strict_encode64('wiki-app:wiki-secret')}" }))
        .to have_been_made
    end

    it 'declares the enterprise-managed authorization extension with every request' do
      wiki_class.new(user: 'ada').tools

      expect(declared_extensions).to eq([{ 'io.modelcontextprotocol/enterprise-managed-authorization' => {} }])
    end

    it 'forwards nothing the identity provider issues but an identity assertion grant' do
      issues_grant('urn:ietf:params:oauth:token-type:access_token')

      expect { wiki_class.new(user: 'ada').tools }
        .to raise_error(RubyLLM::UnauthorizedError, 'https://idp.example.com did not issue an identity assertion grant')
      expect(a_request(:post, 'https://auth.example.com/token')).not_to have_been_made
    end

    it "raises the identity provider's refusal" do
      stub_request(:post, 'https://idp.example.com/token')
        .to_return(status: 400, body: { error: 'invalid_grant', error_description: 'The ID token expired' }.to_json)

      expect { wiki_class.new(user: 'ada').tools }
        .to raise_error(RubyLLM::UnauthorizedError, 'idp.example.com refused the request: The ID token expired')
    end
  end

  describe 'servers that require DPoP' do
    def public_key(jwk)
      point = "\x04".b + Base64.urlsafe_decode64(jwk['x']) + Base64.urlsafe_decode64(jwk['y'])
      algorithm = OpenSSL::ASN1::Sequence([OpenSSL::ASN1::ObjectId('id-ecPublicKey'),
                                           OpenSSL::ASN1::ObjectId('prime256v1')])
      OpenSSL::PKey.read(OpenSSL::ASN1::Sequence([algorithm, OpenSSL::ASN1::BitString(point)]).to_der)
    end

    def proved(proof)
      verified(proof, public_key(JSON.parse(Base64.urlsafe_decode64(proof.split('.').first))['jwk']))
    end

    def requires_dpop(nonce: nil, supplies: nil, challenge: "DPoP resource_metadata=\"#{metadata_url}\"")
      stub_request(:post, server_url).to_return do |request|
        proof = request.headers['Dpop']
        if proof.nil? || !request.headers['Authorization'].to_s.start_with?('DPoP access-')
          { status: 401, headers: { 'WWW-Authenticate' => challenge } }
        elsif nonce && proved(proof).last['nonce'] != nonce
          { status: 401, headers: { 'WWW-Authenticate' => 'DPoP error="use_dpop_nonce"', 'DPoP-Nonce' => nonce } }
        else
          message = JSON.parse(request.body)
          result = message['method'] == 'server/discover' ? { supportedVersions: ['2026-07-28'] } : { tools: [] }
          { headers: { 'Content-Type' => 'application/json', 'DPoP-Nonce' => supplies }.compact,
            body: { jsonrpc: '2.0', id: message['id'], result: }.to_json }
        end
      end
    end

    def keeps_sessions
      stub_request(:post, server_url).to_return do |request|
        next { status: 401, headers: { 'WWW-Authenticate' => "DPoP resource_metadata=\"#{metadata_url}\"" } } unless
          request.headers['Authorization'].to_s.start_with?('DPoP access-')

        message = JSON.parse(request.body)
        result = if message['method'] == 'initialize'
                   { protocolVersion: '2025-06-18', capabilities: { tools: { listChanged: true } } }
                 else
                   { tools: [] }
                 end
        next { status: 404, body: '' } if message['method'] == 'server/discover'
        next { status: 202, body: '' } unless message['id']

        { headers: { 'Content-Type' => 'application/json', 'Mcp-Session-Id' => 'session-1' },
          body: { jsonrpc: '2.0', id: message['id'], result: }.to_json }
      end
    end

    def metadata_url = 'https://mcp.example.com/.well-known/oauth-protected-resource/mcp'

    def proofs_sent_to(url)
      proofs = []
      expect(a_request(:post, url).with { |request| proofs << request.headers['Dpop'] }).to have_been_made.at_least_once
      proofs.compact.map { |proof| proved(proof) }
    end

    before do
      requires_dpop
      stub_request(:post, 'https://auth.example.com/token').to_return do |request|
        refreshing = URI.decode_www_form(request.body).to_h['grant_type'] == 'refresh_token'
        { body: { access_token: refreshing ? 'access-2' : 'access-1', refresh_token: 'refresh-1', expires_in: 3600,
                  token_type: request.headers['Dpop'] ? 'DPoP' : 'Bearer' }.to_json }
      end
    end

    it 'binds tokens to a key kept with the credentials and proves possession of it on every request' do
      linear.authorize(callback(linear.authorization_url(redirect_uri:)))
      linear_class.new(user: 'ada').tools

      (token_header, token_claims), = proofs_sent_to('https://auth.example.com/token')
      expect(token_header).to include('typ' => 'dpop+jwt', 'alg' => 'ES256')
      expect(token_header['jwk'].keys).to contain_exactly('kty', 'crv', 'x', 'y')
      expect(token_claims).to include('htm' => 'POST', 'htu' => 'https://auth.example.com/token')
      expect(token_claims).not_to include('ath', 'nonce')
      requests = proofs_sent_to(server_url)
      expect(requests.size).to eq(2)
      expect(requests.map { |header, _| header['jwk'] }.uniq).to eq([token_header['jwk']])
      expect(requests.map(&:last)).to all(include('htm' => 'POST', 'htu' => server_url,
                                                  'ath' => Base64.urlsafe_encode64(Digest::SHA256.digest('access-1'),
                                                                                   padding: false)))
      expect(requests.map { |_, claims| claims['jti'] }.uniq.size).to eq(2)
      expect(RubyLLM.config.mcp_credential_store.read("ada@#{server_url}"))
        .to include('token_type' => 'DPoP', 'dpop_key' => a_string_starting_with('-----BEGIN PRIVATE KEY-----'))
    end

    it 'refreshes with a proof from the same key' do
      linear.authorize(callback(linear.authorization_url(redirect_uri:)))
      store = RubyLLM.config.mcp_credential_store
      store.write("ada@#{server_url}", store.read("ada@#{server_url}").merge('expires_at' => 0))

      linear_class.new(user: 'ada').tools

      exchange, refresh = proofs_sent_to('https://auth.example.com/token').map(&:first)
      expect(refresh['jwk']).to eq(exchange['jwk'])
      expect(a_request(:post, server_url).with(headers: { 'Authorization' => 'DPoP access-2' })).to have_been_made.twice
    end

    it "retries a token request with the authorization server's nonce" do
      requests = 0
      stub_request(:post, 'https://auth.example.com/token').to_return do
        next { status: 400, headers: { 'DPoP-Nonce' => 'as-nonce' }, body: { error: 'use_dpop_nonce' }.to_json } if
          (requests += 1) == 1

        { body: { access_token: 'access-1', token_type: 'DPoP', expires_in: 3600 }.to_json }
      end

      linear.authorize(callback(linear.authorization_url(redirect_uri:)))

      expect(proofs_sent_to('https://auth.example.com/token').map { |_, claims| claims['nonce'] })
        .to eq([nil, 'as-nonce'])
      expect(linear).to be_authorized
    end

    it "retries a request with the server's nonce" do
      linear.authorize(callback(linear.authorization_url(redirect_uri:)))
      requires_dpop(nonce: 'rs-nonce')

      expect(linear_class.new(user: 'ada').tools).to eq([])

      expect(proofs_sent_to(server_url).map { |_, claims| claims['nonce'] }).to eq([nil, 'rs-nonce', 'rs-nonce'])
    end

    it 'proves possession with the HTTP method of each request' do
      keeps_sessions
      linear.authorize(callback(linear.authorization_url(redirect_uri:)))
      streams = Queue.new
      stub_request(:get, server_url).to_return do |request|
        streams << request.headers['Dpop']
        { status: 405 }
      end
      ended = stub_request(:delete, server_url).to_return(status: 204)

      mcp = linear_class.new(user: 'ada')
      mcp.listen
      stream = Timeout.timeout(5) { streams.pop }
      mcp.close

      expect(proofs_sent_to(server_url).map(&:last)).to all(include('htm' => 'POST'))
      expect(proved(stream).last).to include('htm' => 'GET', 'htu' => server_url)
      expect(ended.with { |request| proved(request.headers['Dpop']).last['htm'] == 'DELETE' }).to have_been_made
    end

    it 'signs the next proof with the nonce the server sends with a response' do
      linear.authorize(callback(linear.authorization_url(redirect_uri:)))
      requires_dpop(supplies: 'rs-nonce')

      linear_class.new(user: 'ada').tools

      expect(proofs_sent_to(server_url).map { |_, claims| claims['nonce'] }).to eq([nil, 'rs-nonce'])
    end

    it "gets a token for the app's first request, then retries it with the server's nonce" do
      requires_dpop(nonce: 'rs-nonce')
      url = server_url
      reports = Class.new(RubyLLM::MCP) do
        url url
        oauth grant: :client_credentials, client_id: 'reports', client_secret: 'shh'
      end.new

      expect(reports.tools).to eq([])

      expect(proofs_sent_to(server_url).map { |_, claims| claims['nonce'] }).to eq([nil, 'rs-nonce', 'rs-nonce'])
    end

    it 'binds tokens the app requests for itself when the metadata requires it' do
      requires_dpop(challenge: "Bearer resource_metadata=\"#{metadata_url}\"")
      stub_request(:get, metadata_url).to_return(
        body: { resource: server_url, authorization_servers: ['https://auth.example.com'],
                dpop_bound_access_tokens_required: true }.to_json
      )
      url = server_url
      reports = Class.new(RubyLLM::MCP) do
        url url
        oauth grant: :client_credentials, client_id: 'reports', client_secret: 'shh'
      end.new

      expect(reports.tools).to eq([])

      expect(proofs_sent_to('https://auth.example.com/token').size).to eq(1)
      expect(proofs_sent_to(server_url).size).to eq(2)
    end

    it 'keeps bearer tokens for servers that also accept them' do
      challenge = "Bearer resource_metadata=\"#{metadata_url}\", DPoP algs=\"ES256\""
      stub_request(:post, server_url).to_return(status: 401, headers: { 'WWW-Authenticate' => challenge })

      linear.authorize(callback(linear.authorization_url(redirect_uri:)))

      expect(a_request(:post, 'https://auth.example.com/token').with(headers: { 'DPoP' => /.+/ })).not_to have_been_made
    end
  end

  it 'refuses grants it does not know' do
    expect { Class.new(RubyLLM::MCP) { oauth grant: :password } }
      .to raise_error(ArgumentError, 'Unknown OAuth grant: password')
  end
end
