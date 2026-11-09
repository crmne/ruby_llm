# frozen_string_literal: true

require 'spec_helper'
require 'googleauth'

RSpec.describe RubyLLM::Providers::VertexAI::Credentials do
  let(:tokens) { %w[token-1 token-2 token-3] }
  let(:expires_in) { [3600] }

  before { stub_request(:any, /.*/).to_raise('Unexpected network request') }

  def service_account_key(email)
    JSON.generate(
      type: 'service_account', project_id: 'test-project', private_key_id: 'test-key',
      private_key: OpenSSL::PKey::RSA.new(2048).to_pem, client_email: email, client_id: '1'
    )
  end

  def config(key, token_timeout: nil)
    RubyLLM::Configuration.new.tap do |config|
      config.vertexai_service_account_key = key
      config.vertexai_token_timeout = token_timeout
    end
  end

  def stub_token_endpoint(latency: 0)
    issued = tokens.dup
    lifetimes = expires_in.dup
    stub_request(:post, %r{\Ahttps://[a-z0-9]+\.googleapis\.com/(?:oauth2/v4/)?token\z}).to_return do
      sleep latency
      { status: 200, headers: { 'Content-Type' => 'application/json' },
        body: JSON.generate(access_token: issued.shift, expires_in: lifetimes.shift || 3600, token_type: 'Bearer') }
    end
  end

  def authorization(key, token_timeout: nil)
    described_class.for(config(key, token_timeout:)).headers[:authorization]
  end

  it 'fetches one access token for every provider that shares a service account key' do
    endpoint = stub_token_endpoint
    key = service_account_key('ruby@test-project.iam.gserviceaccount.com')

    expect(Array.new(3) { authorization(key) }).to eq(['Bearer token-1'] * 3)
    expect(endpoint).to have_been_requested.once
  end

  it 'never shares a token between service account keys' do
    endpoint = stub_token_endpoint
    tenant_a = service_account_key('tenant-a@test-project.iam.gserviceaccount.com')
    tenant_b = service_account_key('tenant-b@test-project.iam.gserviceaccount.com')

    expect([authorization(tenant_a), authorization(tenant_b), authorization(tenant_a)])
      .to eq(['Bearer token-1', 'Bearer token-2', 'Bearer token-1'])
    expect(endpoint).to have_been_requested.twice
  end

  context 'when the token is about to expire' do
    let(:expires_in) { [30, 3600] }

    it 'fetches a new one' do
      endpoint = stub_token_endpoint
      key = service_account_key('ruby@test-project.iam.gserviceaccount.com')

      expect(Array.new(3) { authorization(key) }).to eq(['Bearer token-1', 'Bearer token-2', 'Bearer token-2'])
      expect(endpoint).to have_been_requested.twice
    end
  end

  it 'fetches one token when threads ask for it together' do
    endpoint = stub_token_endpoint(latency: 0.1)
    key = service_account_key('ruby@test-project.iam.gserviceaccount.com')

    headers = Array.new(8) { Thread.new { authorization(key) } }.map(&:value)

    expect(headers.uniq).to eq(['Bearer token-1'])
    expect(endpoint).to have_been_requested.once
  end

  it 'fetches one token when fibers ask for it together' do
    endpoint = stub_token_endpoint(latency: 0.1)
    key = service_account_key('ruby@test-project.iam.gserviceaccount.com')

    headers = in_reactor { |task| Array.new(8) { task.async { authorization(key) } }.map(&:wait) }

    expect(headers.uniq).to eq(['Bearer token-1'])
    expect(endpoint).to have_been_requested.once
  end

  context 'when the token endpoint never answers' do
    let(:silent) { TCPServer.new('127.0.0.1', 0) }

    around do |example|
      WebMock.disable!
      accepted = []
      acceptor = Thread.new { loop { accepted << silent.accept } }
      example.run
    ensure
      WebMock.enable!
      acceptor.kill.join
      silent.close
      accepted.each(&:close)
    end

    it 'gives up on the token after the token timeout' do
      credentials = described_class.new(service_account_key('ruby@test-project.iam.gserviceaccount.com'),
                                        token_timeout: 0.1)
      credentials.authorizer.token_credential_uri = "http://127.0.0.1:#{silent.addr[1]}/token"
      allow(credentials.authorizer).to receive(:sleep)

      expect { Timeout.timeout(5) { credentials.headers } }.to raise_error(Google::Auth::AuthorizationError)
    end
  end

  context 'when Faraday has a default connection of its own' do
    around do |example|
      original = Faraday.default_connection
      example.run
    ensure
      Faraday.default_connection = original
    end

    def token_adapter(timeouts)
      Class.new(Faraday::Adapter) do
        define_method(:call) do |env|
          super(env)
          timeouts << env.request.timeout
          body = JSON.generate(access_token: 'adapter-token', expires_in: 3600, token_type: 'Bearer')
          save_response(env, 200, body, { 'Content-Type' => 'application/json' })
          @app.call(env)
        end
      end
    end

    def use_default_connection(timeouts)
      Faraday.default_connection = Faraday.new(request: { timeout: 3 }) do |faraday|
        faraday.adapter(token_adapter(timeouts))
      end
    end

    it 'leaves googleauth on it without a token timeout' do
      timeouts = []
      use_default_connection(timeouts)

      authorization(service_account_key('ruby@test-project.iam.gserviceaccount.com'))

      expect(timeouts).to eq([3])
    end

    it 'fetches the token through it with the token timeout' do
      timeouts = []
      use_default_connection(timeouts)
      key = service_account_key('ruby@test-project.iam.gserviceaccount.com')

      expect(authorization(key, token_timeout: 10)).to eq('Bearer adapter-token')
      expect(timeouts).to eq([10])
    end
  end

  it 'keeps credentials that fetch tokens through their own connection' do
    external_account = Object.new
    def external_account.apply(_headers) = { authorization: 'Bearer external-token' }
    allow(Google::Auth).to receive(:get_application_default).and_return(external_account)

    expect(described_class.new(nil, token_timeout: 5).headers[:authorization]).to eq('Bearer external-token')
  end

  it 'shares credentials only between configurations with the same token timeout' do
    key = service_account_key('ruby@test-project.iam.gserviceaccount.com')
    credentials = described_class.for(config(key, token_timeout: 3))

    expect(described_class.for(config(key, token_timeout: 3))).to be(credentials)
    expect(described_class.for(config(key, token_timeout: 5))).not_to be(credentials)
  end

  it 'fetches its own token in a forked child' do
    endpoint = stub_token_endpoint
    key = service_account_key('ruby@test-project.iam.gserviceaccount.com')
    authorization(key)
    allow(Process).to receive(:pid).and_return(Process.pid + 1)

    expect(authorization(key)).to eq('Bearer token-2')
    expect(endpoint).to have_been_requested.twice
  end
end
