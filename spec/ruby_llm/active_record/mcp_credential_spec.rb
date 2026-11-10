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

  describe 'across processes' do
    let(:server_url) { 'https://mcp.example.com/mcp' }
    let(:key) { "#{owner.to_gid}@#{server_url}" }
    let(:server) { { 'issuer' => 'https://auth.example.com', 'token_endpoint' => 'https://auth.example.com/token' } }
    let(:tokens) { { access_token: 'access-2', refresh_token: 'refresh-2', expires_in: 3600 } }

    before { skip 'needs fork' unless RUBY_ENGINE == 'ruby' }

    def oauth = RubyLLM::MCP::OAuth.new(server_url, owner:)

    def store_expired_tokens
      described_class.write(key, { 'access_token' => 'access-1', 'refresh_token' => 'refresh-1', 'expires_at' => 0,
                                   'client_id' => 'client', 'issuer' => server['issuer'], 'server' => server }, owner:)
    end

    def store_pending_authorization
      described_class.write(key, { 'pending' => {
                              'client_id' => 'client', 'state' => 'state-1', 'verifier' => 'verifier-1',
                              'redirect_uri' => 'https://app.example.com/callback', 'issuer' => server['issuer'],
                              'expires_at' => Time.now.to_i + 600, 'server' => server
                            } }, owner:)
    end

    # Runs +first+ in a process until it asks the token endpoint, then
    # +second+ in another until SQLite makes it wait for the write lock,
    # then lets both finish. Returns whether each succeeded and the lines
    # they reported, in order.
    def contend(first, second)
      lines, events = IO.pipe
      release, resume = IO.pipe
      stub_request(:post, server['token_endpoint']).to_return do
        events.puts 'exchanging'
        release.gets
        { body: tokens.to_json }
      end
      workers = [run_worker(events, 'first', &first)]
      reported = [Timeout.timeout(10) { lines.gets.chomp }]
      workers << run_worker(events, 'second') do
        report_lock_wait(events)
        second.call
      end
      reported << Timeout.timeout(10) { lines.gets.chomp }
      resume.puts 'go', 'go'
      succeeded = []
      succeeded << reap(workers.shift) until workers.empty?
      events.close
      [succeeded, reported + lines.read.lines(chomp: true)]
    ensure
      workers&.each do |worker|
        Process.kill(:KILL, worker)
        Process.wait(worker)
      end
      [lines, events, release, resume].compact.each { |io| io.close unless io.closed? }
    end

    def reap(worker)
      Timeout.timeout(10) { Process.wait2(worker).last.success? }
    rescue Timeout::Error
      Process.kill(:KILL, worker)
      Process.wait(worker)
      false
    end

    def run_worker(events, name)
      described_class.connection_pool.disconnect!
      fork do
        status = 1
        events.puts "#{name} #{yield}"
        status = 0
      rescue Exception => e # rubocop:disable Lint/RescueException
        events.puts "#{name} raised #{e.class}: #{e.message.lines.first&.chomp}"
      ensure
        exit!(status)
      end
    end

    def report_lock_wait(events)
      reported = false
      described_class.connection.raw_connection.busy_handler do |attempts|
        events.puts 'waiting' unless reported
        reported = true
        sleep 0.001
        attempts < 10_000
      end
    end

    it 'keeps credentials forgotten while another process refreshes them' do
      store_expired_tokens

      succeeded, reported = contend(-> { oauth.access_token }, lambda {
        oauth.deauthorize
        'deauthorized'
      })

      expect(succeeded).to eq([true, true])
      expect(reported.first(2)).to eq(%w[exchanging waiting])
      expect(reported.drop(2)).to contain_exactly('first access-2', 'second deauthorized')
      expect(described_class.where(key:)).not_to exist
    end

    it 'keeps credentials forgotten while another process completes their authorization' do
      store_pending_authorization

      succeeded, reported = contend(lambda {
        oauth.authorize(code: 'code-1', state: 'state-1', iss: server['issuer'])
        'authorized'
      }, lambda {
        oauth.deauthorize
        'deauthorized'
      })

      expect(succeeded).to eq([true, true])
      expect(reported.first(2)).to eq(%w[exchanging waiting])
      expect(reported.drop(2)).to contain_exactly('first authorized', 'second deauthorized')
      expect(described_class.where(key:)).not_to exist
    end

    it 'lets one process refresh a grant while the others wait for its token' do
      store_expired_tokens

      succeeded, reported = contend(-> { oauth.access_token }, -> { oauth.access_token })

      expect(succeeded).to eq([true, true])
      expect(reported.first(2)).to eq(%w[exchanging waiting])
      expect(reported.drop(2)).to contain_exactly('first access-2', 'second access-2')
      expect(described_class.read(key)).to include('access_token' => 'access-2', 'refresh_token' => 'refresh-2')
    end
  end
end
