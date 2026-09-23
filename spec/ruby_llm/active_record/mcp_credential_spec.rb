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

  it 'replaces and deletes credentials' do
    described_class.write('key', { 'access_token' => 'first' })
    described_class.write('key', { 'access_token' => 'second' })

    expect(described_class.read('key')).to eq('access_token' => 'second')
    expect { described_class.delete('key') }.to change(described_class, :count).by(-1)
  end
end
