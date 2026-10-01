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

  def config(key)
    RubyLLM::Configuration.new.tap { |config| config.vertexai_service_account_key = key }
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

  def authorization(key)
    described_class.for(config(key)).headers[:authorization]
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

  it 'fetches its own token in a forked child' do
    endpoint = stub_token_endpoint
    key = service_account_key('ruby@test-project.iam.gserviceaccount.com')
    authorization(key)
    allow(Process).to receive(:pid).and_return(Process.pid + 1)

    expect(authorization(key)).to eq('Bearer token-2')
    expect(endpoint).to have_been_requested.twice
  end
end
