# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::MCPCredential do
  let(:owner) { Chat.create!(model: model_for(:openai, :temperature)) }

  it 'is the credential store in Rails' do
    expect(RubyLLM.config.mcp_credential_store).to be(described_class)
  end

  it 'keeps credentials encrypted, with their owner' do
    described_class.write('key', { 'access_token' => 'secret-token' }, owner:)

    expect(described_class.read('key')).to eq('access_token' => 'secret-token')
    expect(described_class.find_by(key: 'key').owner).to eq(owner)
    expect(described_class.connection.select_value("SELECT data FROM ruby_llm_mcp_credentials WHERE key = 'key'"))
      .not_to include('secret-token')
  end

  it 'deletes the row when the server is deauthorized' do
    server_url = 'https://mcp.example.com/mcp'
    key = "#{owner.to_gid}@#{server_url}"
    described_class.write(key, { 'access_token' => 'access-1' }, owner:)

    RubyLLM::MCP::OAuth.new(server_url, owner:).deauthorize

    expect(described_class.where(key:)).not_to exist
  end

  it 'keeps the tokens of an authorization it completes' do
    server_url = 'https://mcp.example.com/mcp'
    key = "#{owner.to_gid}@#{server_url}"
    server = { 'issuer' => 'https://auth.example.com', 'token_endpoint' => 'https://auth.example.com/token' }
    described_class.write(key, { 'pending' => {
                            'client_id' => 'client', 'state' => 'state-1', 'verifier' => 'verifier-1',
                            'redirect_uri' => 'https://app.example.com/callback', 'issuer' => server['issuer'],
                            'expires_at' => Time.now.to_i + 600, 'server' => server
                          } }, owner:)
    stub_request(:post, 'https://auth.example.com/token')
      .to_return(body: { access_token: 'access-1', expires_in: 3600 }.to_json)

    RubyLLM::MCP::OAuth.new(server_url, owner:).authorize(code: 'code-1', state: 'state-1', iss: server['issuer'])

    expect(described_class.read(key)).to include('access_token' => 'access-1', 'client_id' => 'client')
    expect(described_class.read(key)).not_to have_key('pending')
  end

  it 'lets one process refresh a grant while the others wait for its token' do
    skip 'needs fork' unless RUBY_ENGINE == 'ruby'
    server_url = 'https://mcp.example.com/mcp'
    key = "#{owner.to_gid}@#{server_url}"
    described_class.write(key, {
                            'access_token' => 'access-1', 'refresh_token' => 'refresh-1', 'expires_at' => 0,
                            'client_id' => 'client', 'issuer' => 'https://auth.example.com',
                            'server' => { 'issuer' => 'https://auth.example.com',
                                          'token_endpoint' => 'https://auth.example.com/token' }
                          }, owner:)
    refreshes, refreshed = IO.pipe
    tokens, token = IO.pipe
    stub_request(:post, 'https://auth.example.com/token').to_return do
      refreshed.puts('refresh')
      sleep 0.2
      { body: { access_token: 'access-2', refresh_token: 'refresh-2', expires_in: 3600 }.to_json }
    end
    described_class.connection_pool.disconnect!

    workers = Array.new(2) do
      fork do
        token.puts RubyLLM::MCP::OAuth.new(server_url, owner:, scopes: nil, client_id: nil, client_secret: nil)
                                      .access_token
      ensure
        exit!
      end
    end
    workers.each { |worker| Process.wait(worker) }
    [refreshed, token].each(&:close)

    expect(tokens.read.split).to eq(%w[access-2 access-2])
    expect(refreshes.read.split).to eq(['refresh'])
    expect(described_class.read(key)['refresh_token']).to eq('refresh-2')
  end

  it 'keeps the key of DPoP-bound tokens with them, encrypted' do
    key = OpenSSL::PKey::EC.generate('prime256v1')
    server_url = 'https://mcp.example.com/mcp'
    described_class.write("#{owner.to_gid}@#{server_url}", {
                            'access_token' => 'access-1', 'token_type' => 'DPoP', 'dpop_key' => key.private_to_pem
                          }, owner:)

    headers = RubyLLM::MCP::OAuth.new(server_url, owner:).authorization_headers

    jwk = JSON.parse(Base64.urlsafe_decode64(headers['DPoP'].split('.').first))['jwk']
    expect(headers['Authorization']).to eq('DPoP access-1')
    expect(Base64.urlsafe_decode64(jwk['x'])).to eq(key.public_key.to_octet_string(:uncompressed)[1, 32])
    expect(described_class.connection.select_value('SELECT data FROM ruby_llm_mcp_credentials'))
      .not_to include('PRIVATE KEY')
  end

  it 'replaces and deletes credentials' do
    described_class.write('key', { 'access_token' => 'first' })
    described_class.write('key', { 'access_token' => 'second' })

    expect(described_class.read('key')).to eq('access_token' => 'second')
    expect { described_class.delete('key') }.to change(described_class, :count).by(-1)
  end

  it 'replaces credentials another process wrote first' do
    allow(described_class).to receive(:new).and_wrap_original do |original, *arguments, &block|
      allow(described_class).to receive(:new).and_call_original
      Thread.new { described_class.create!(key: 'key', data: { 'access_token' => 'first' }) }.join
      original.call(*arguments, &block)
    end

    described_class.write('key', { 'access_token' => 'second' })

    expect(described_class.read('key')).to eq('access_token' => 'second')
  end
end
