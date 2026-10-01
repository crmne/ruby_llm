# frozen_string_literal: true

require 'spec_helper'
require 'google/cloud/storage'

RSpec.describe RubyLLM::Protocols::VertexAI::Files do
  before do
    stub_request(:any, /.*/).to_raise('Unexpected network request')
    allow(Google::Cloud::Storage).to receive(:new) { Object.new }
  end

  def config(project = 'test-project', key: nil)
    RubyLLM::Configuration.new.tap do |config|
      config.vertexai_project_id = project
      config.vertexai_location = 'global'
      config.vertexai_service_account_key = key
    end
  end

  def storage(config)
    provider = RubyLLM::Providers::VertexAI.new(config)
    described_class.new(provider).send(:storage)
  end

  def service_account_key(email)
    JSON.generate(type: 'service_account', project_id: 'test-project', private_key_id: 'test-key',
                  private_key: OpenSSL::PKey::RSA.new(2048).to_pem, client_email: email, client_id: '1')
  end

  def with_env(name, value)
    original = ENV.fetch(name, nil)
    ENV[name] = value
    yield
  ensure
    ENV[name] = original
  end

  it 'shares one Cloud Storage client per project with Application Default Credentials' do
    shared = storage(config)

    expect(storage(config)).to be(shared)
    expect(storage(config('other-project'))).not_to be(shared)
    expect(Google::Cloud::Storage).to have_received(:new).with(project_id: 'test-project').once
  end

  it 'builds another client when the credential environment changes' do
    shared = storage(config)

    expect(with_env('STORAGE_KEYFILE', '/etc/storage-keyfile.json') { storage(config) }).not_to be(shared)
    expect(with_env('GOOGLE_APPLICATION_CREDENTIALS', '/etc/adc.json') { storage(config) }).not_to be(shared)
  end

  it 'builds another client when Cloud Storage settings change' do
    shared = storage(config)
    Google::Cloud::Storage.configure.endpoint = 'https://storage.example.test/'

    expect(storage(config)).not_to be(shared)
  ensure
    Google::Cloud::Storage.configure.reset!(:endpoint)
  end

  it 'never shares a client between service account keys' do
    tenant_a = config(key: service_account_key('tenant-a@test-project.iam.gserviceaccount.com'))
    tenant_b = config(key: service_account_key('tenant-b@test-project.iam.gserviceaccount.com'))

    shared = storage(tenant_a)

    expect(storage(tenant_b)).not_to be(shared)
    expect(storage(tenant_a)).to be(shared)
    expect(Google::Cloud::Storage).to have_received(:new)
      .with(project_id: 'test-project', credentials: RubyLLM::Providers::VertexAI::Credentials.for(tenant_a).authorizer)
  end

  it 'hands every thread that asks at once the same client' do
    clients = Array.new(8) { Thread.new { storage(config) } }.map(&:value)

    expect(clients.uniq.size).to eq(1)
  end

  it 'builds its own client in a forked child' do
    parent = storage(config)
    allow(Process).to receive(:pid).and_return(Process.pid + 1)

    expect(storage(config)).not_to be(parent)
  end
end
