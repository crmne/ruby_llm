# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::MCPCredential do
  let(:owner) { Chat.create!(model: 'gpt-4.1-nano') }

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
end
