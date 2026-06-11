# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock do
  let(:credentials_class) { Struct.new(:access_key_id, :secret_access_key, :session_token, keyword_init: true) }
  let(:credential_provider_class) { Struct.new(:credentials, keyword_init: true) }

  def bedrock_config(region: 'us-east-1', api_key: nil, secret_key: nil, session_token: nil, credential_provider: nil)
    RubyLLM::Configuration.new.tap do |config|
      config.bedrock_region = region
      config.bedrock_api_key = api_key
      config.bedrock_secret_key = secret_key
      config.bedrock_session_token = session_token
      config.bedrock_credential_provider = credential_provider
    end
  end

  def credentials(access_key_id: 'provider-key', secret_access_key: 'provider-secret', session_token: 'provider-token')
    credentials_class.new(access_key_id:, secret_access_key:, session_token:)
  end

  def credential_provider(credentials = self.credentials)
    credential_provider_class.new(credentials:)
  end

  describe '.configuration_options' do
    it 'registers credential providers as a Bedrock option' do
      expect(RubyLLM::Configuration.options).to include(:bedrock_credential_provider)
    end
  end

  describe '.configured?' do
    it 'accepts static credentials with a region' do
      config = bedrock_config(api_key: 'static-key', secret_key: 'static-secret')

      expect(described_class.configured?(config)).to be(true)
    end

    it 'accepts a credential provider with a region' do
      config = bedrock_config(credential_provider: credential_provider)

      expect(described_class.configured?(config)).to be(true)
    end

    it 'rejects a region without credentials' do
      config = bedrock_config

      expect(described_class.configured?(config)).to be(false)
    end

    it 'rejects credentials without a region' do
      config = bedrock_config(region: nil, credential_provider: credential_provider)

      expect(described_class.configured?(config)).to be(false)
    end

    it 'rejects an invalid credential provider instead of falling back to static keys' do
      config = bedrock_config(
        api_key: 'static-key',
        secret_key: 'static-secret',
        credential_provider: Object.new
      )

      expect(described_class.configured?(config)).to be(false)
    end
  end

  describe '#initialize' do
    it 'explains the alternative credential shapes' do
      expect { described_class.new(bedrock_config) }
        .to raise_error(RubyLLM::ConfigurationError, /bedrock_credential_provider or bedrock_api_key/)
    end

    it 'explains an invalid credential provider' do
      config = bedrock_config(
        api_key: 'static-key',
        secret_key: 'static-secret',
        credential_provider: Object.new
      )

      expect { described_class.new(config) }
        .to raise_error(RubyLLM::ConfigurationError, /bedrock_credential_provider responding to #credentials/)
    end
  end

  describe '#sign_headers' do
    it 'signs with static credentials' do
      provider = described_class.new(
        bedrock_config(api_key: 'static-key', secret_key: 'static-secret', session_token: 'static-token')
      )

      headers = provider.sign_headers('POST', '/model/anthropic.claude-haiku/converse', '{}')

      expect(headers['Authorization']).to include('Credential=static-key/')
      expect(headers['X-Amz-Security-Token']).to eq('static-token')
    end

    it 'signs with a credential provider instead of configured static credentials' do
      provider = described_class.new(
        bedrock_config(
          api_key: 'static-key',
          secret_key: 'static-secret',
          session_token: 'static-token',
          credential_provider: credential_provider
        )
      )

      headers = provider.sign_headers('POST', '/model/anthropic.claude-haiku/converse', '{}')

      expect(headers['Authorization']).to include('Credential=provider-key/')
      expect(headers['X-Amz-Security-Token']).to eq('provider-token')
    end
  end

  describe 'model id path encoding' do
    # completion_url/stream_url read only @model, and canonical_uri is a pure path
    # transform, so allocate uninitialized instances to keep these tests focused and
    # credential/connection-free.
    let(:converse) { RubyLLM::Protocols::Converse.allocate }
    let(:arn) { 'arn:aws:bedrock:us-west-2:123:application-inference-profile/p' }

    def with_model(id)
      converse.instance_variable_set(:@model, instance_double(RubyLLM::Model::Info, id: id))
    end

    it 'keeps an application inference profile ARN as a single path segment in the converse URL' do
      with_model(arn)
      # The ARN's internal "/" is percent-encoded so it is not parsed as a path separator
      # (which would truncate the modelId to ".../application-inference-profile").
      expect(converse.send(:completion_url)).to eq(
        '/model/arn:aws:bedrock:us-west-2:123:application-inference-profile%2Fp/converse'
      )
    end

    it 'encodes the ARN for the converse-stream URL too' do
      with_model(arn)
      expect(converse.send(:stream_url)).to eq(
        '/model/arn:aws:bedrock:us-west-2:123:application-inference-profile%2Fp/converse-stream'
      )
    end

    it 'leaves ordinary model ids (including a ":" version suffix) unchanged' do
      with_model('us.anthropic.claude-sonnet-4-5-20250929-v1:0')
      expect(converse.send(:completion_url)).to eq(
        '/model/us.anthropic.claude-sonnet-4-5-20250929-v1:0/converse'
      )
    end

    it 'signs the ARN as one segment (SigV4 canonical path double-encodes "/", not truncates)' do
      with_model(arn)
      path = URI.parse(converse.send(:completion_url)).path
      # canonical_uri re-encodes each segment, turning the already-encoded "%2F" into
      # "%252F" — so the profile id stays inside the modelId segment rather than becoming
      # its own path segment, keeping the signed path consistent with the sent path.
      expect(described_class.allocate.send(:canonical_uri, path)).to eq(
        '/model/arn%3Aaws%3Abedrock%3Aus-west-2%3A123%3Aapplication-inference-profile%252Fp/converse'
      )
    end
  end
end
