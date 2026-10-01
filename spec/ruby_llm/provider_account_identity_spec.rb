# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Provider do
  def identity(slug, **settings)
    config = RubyLLM::Configuration.new
    settings.each { |option, value| config.public_send("#{option}=", value) }
    described_class.resolve!(slug).new(config).account_identity
  end

  {
    openai: %i[openai_api_key openai_api_base openai_organization_id openai_project_id],
    anthropic: %i[anthropic_api_key anthropic_api_base],
    gemini: %i[gemini_api_key gemini_api_base],
    openrouter: %i[openrouter_api_key openrouter_api_base],
    xai: %i[xai_api_key xai_api_base],
    deepseek: %i[deepseek_api_key deepseek_api_base]
  }.each do |slug, (key, *scope)|
    it "identifies a #{slug} account by its API key and endpoint" do
      account = identity(slug, key => 'sk-one')

      expect(account).to match(/\A\h{64}\z/)
      expect(account).not_to include('sk-one')
      expect(identity(slug, key => 'sk-one')).to eq(account)
      expect(identity(slug, key => 'sk-two')).not_to eq(account)
      scope.each { |option| expect(identity(slug, key => 'sk-one', option => 'https://other.test')).not_to eq(account) }
    end
  end

  it 'identifies an Azure resource whichever credential signs its requests' do
    base = 'https://tenant.openai.azure.com'
    account = identity(:azure, azure_api_base: base, azure_api_key: 'key-one')

    expect(account).to match(/\A\h{64}\z/)
    expect(identity(:azure, azure_api_base: "#{base}/openai/v1", azure_api_key: 'key-two')).to eq(account)
    expect(identity(:azure, azure_api_base: base, azure_ai_auth_token: 'rotating-token')).to eq(account)
    expect(identity(:azure, azure_api_base: 'https://other.openai.azure.com', azure_api_key: 'key-one'))
      .not_to eq(account)
  end

  it 'identifies Vertex AI uploads by the bucket that holds them' do
    project = { vertexai_project_id: 'one', vertexai_location: 'global' }
    account = identity(:vertexai, **project, vertexai_batch_gcs_uri: 'gs://bucket/ruby_llm')

    elsewhere = project.merge(vertexai_location: 'europe-west4', vertexai_service_account_key: '{"key":"rotated"}')

    expect(account).to match(/\A\h{64}\z/)
    expect(identity(:vertexai, **elsewhere, vertexai_batch_gcs_uri: 'gs://bucket/ruby_llm')).to eq(account)
    expect(identity(:vertexai, **project, vertexai_batch_gcs_uri: 'gs://other/ruby_llm')).not_to eq(account)
    expect(identity(:vertexai, **project)).to be_nil
  end

  it 'identifies Bedrock uploads by the bucket that holds them' do
    keys = { bedrock_region: 'us-west-2', bedrock_api_key: 'AKIAONE', bedrock_secret_key: 'secret' }
    rotating = { bedrock_region: 'eu-west-1', bedrock_session_token: 'rotating',
                 bedrock_credential_provider: Struct.new(:credentials).new(Object.new) }
    account = identity(:bedrock, **keys, bedrock_batch_s3_uri: 's3://bucket/ruby_llm')

    expect(account).to match(/\A\h{64}\z/)
    expect(identity(:bedrock, **rotating, bedrock_batch_s3_uri: 's3://bucket/ruby_llm')).to eq(account)
    expect(identity(:bedrock, **keys, bedrock_batch_s3_uri: 's3://other/ruby_llm')).not_to eq(account)
    expect(identity(:bedrock, **keys)).to be_nil
  end

  it 'leaves the account unnamed for providers that do not reuse stored uploads' do
    expect(identity(:mistral, mistral_api_key: 'sk-one')).to be_nil
  end
end
