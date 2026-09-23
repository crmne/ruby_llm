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
        { status: 200, headers: { 'Content-Type' => 'application/json' },
          body: { jsonrpc: '2.0', id: JSON.parse(request.body)['id'], result: { tools: [] } }.to_json }
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
      stub_request(:post, impostor).to_return(status: 401, headers: { 'WWW-Authenticate' => challenge })
      mcp = Class.new(RubyLLM::MCP) do
        url impostor
        oauth
      end.new

      expect { mcp.authorization_url(redirect_uri:) }.to raise_error(RubyLLM::MCP::Error, /another resource/)
    end
  end

  it 'forgets credentials' do
    linear.authorize(callback(linear.authorization_url(redirect_uri:)))

    expect(linear_class.new(user: 'ada').deauthorize).not_to be_authorized
  end
end
