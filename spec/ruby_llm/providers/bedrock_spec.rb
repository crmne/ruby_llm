# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock do
  include AWSCredentialsHelpers

  let(:config) { instance_double(RubyLLM::Configuration) }
  let(:provider) { described_class.new(config) }

  before do
    # Default config values needed for provider initialization
    allow(config).to receive_messages(
      bedrock_region: 'us-east-1',
      bedrock_api_key: nil,
      bedrock_secret_key: nil,
      bedrock_session_token: nil,
      bedrock_credential_provider: nil,
      request_timeout: 120,
      max_retries: 3,
      retry_interval: 0.1,
      retry_backoff_factor: 2,
      retry_interval_randomness: 0.5,
      http_proxy: nil,
      logger: nil
    )
  end

  describe '#create_signer' do
    context 'with static credentials' do
      before do
        allow(config).to receive_messages(
          bedrock_api_key: 'test-key-id',
          bedrock_secret_key: 'test-secret-key',
          bedrock_session_token: 'test-session-token'
        )
      end

      it 'creates signer with static credentials' do
        signer = provider.send(:create_signer)

        expect(signer).to be_a(RubyLLM::Providers::Bedrock::Signing::Signer)
        expect(signer.region).to eq('us-east-1')
        expect(signer.service).to eq('bedrock')
        # Verify it was created with a StaticCredentialsProvider wrapping the static creds
        expect(signer.credentials_provider).to be_a(RubyLLM::Providers::Bedrock::Signing::StaticCredentialsProvider)
      end
    end

    context 'with credentials provider' do
      let(:mock_credentials) do
        AWSCredentialsHelpers::MockCredentials.new(
          access_key_id: 'provider-key-id',
          secret_access_key: 'provider-secret-key',
          session_token: 'provider-session-token'
        )
      end
      let(:credentials_provider) { AWSCredentialsHelpers::MockCredentialProvider.new(mock_credentials) }

      before do
        allow(config).to receive(:bedrock_credential_provider).and_return(credentials_provider)
      end

      it 'creates signer with credential provider' do
        signer = provider.send(:create_signer)

        expect(signer).to be_a(RubyLLM::Providers::Bedrock::Signing::Signer)
        expect(signer.region).to eq('us-east-1')
        expect(signer.service).to eq('bedrock')
        expect(signer.credentials_provider).to eq(credentials_provider)
      end

      it 'does not set static credentials when provider is configured' do
        allow(config).to receive_messages(
          bedrock_api_key: 'static-key',
          bedrock_secret_key: 'static-secret',
          bedrock_session_token: 'static-token'
        )

        signer = provider.send(:create_signer)

        # Verify credentials_provider is set and is the one we provided
        expect(signer.credentials_provider).to eq(credentials_provider)
      end

      it 'validates that provider responds to :credentials' do
        allow(provider).to receive(:validate_credential_provider!)

        provider.send(:create_signer)

        expect(provider).to have_received(:validate_credential_provider!).with(credentials_provider)
      end
    end

    context 'with precedence' do
      let(:mock_credentials) do
        AWSCredentialsHelpers::MockCredentials.new(
          access_key_id: 'provider-key',
          secret_access_key: 'provider-secret',
          session_token: 'provider-token'
        )
      end
      let(:credentials_provider) { AWSCredentialsHelpers::MockCredentialProvider.new(mock_credentials) }

      before do
        allow(config).to receive_messages(
          bedrock_credential_provider: credentials_provider,
          bedrock_api_key: 'static-key',
          bedrock_secret_key: 'static-secret',
          bedrock_session_token: 'static-token'
        )
      end

      it 'uses credential_provider over static keys when both are present' do
        signer = provider.send(:create_signer)

        expect(signer).to be_a(RubyLLM::Providers::Bedrock::Signing::Signer)
        expect(signer.credentials_provider).to eq(credentials_provider)
      end
    end
  end

  describe '#validate_credential_provider!' do
    # These tests need a valid provider to initialize, then we test validation with different providers
    let(:mock_credentials) { AWSCredentialsHelpers::MockCredentials.new(access_key_id: 'key', secret_access_key: 'secret') }
    let(:credentials_provider) { AWSCredentialsHelpers::MockCredentialProvider.new(mock_credentials) }

    before do
      allow(config).to receive(:bedrock_credential_provider).and_return(credentials_provider)
    end

    context 'with valid provider' do
      let(:valid_provider) { AWSCredentialsHelpers::MockCredentialProvider.new(mock_credentials) }

      it 'does not raise error when provider responds to :credentials' do
        expect do
          provider.send(:validate_credential_provider!, valid_provider)
        end.not_to raise_error
      end
    end

    context 'with invalid provider' do
      let(:invalid_provider) { AWSCredentialsHelpers::InvalidProvider.new }

      it 'raises ConfigurationError when provider does not respond to :credentials' do
        expect do
          provider.send(:validate_credential_provider!, invalid_provider)
        end.to raise_error(RubyLLM::ConfigurationError,
                           'bedrock_credential_provider must respond to :credentials method')
      end
    end
  end

  describe '#configuration_requirements' do
    context 'with credential provider' do
      let(:mock_credentials) { AWSCredentialsHelpers::MockCredentials.new(access_key_id: 'key', secret_access_key: 'secret') }
      let(:credentials_provider) { AWSCredentialsHelpers::MockCredentialProvider.new(mock_credentials) }

      before do
        allow(config).to receive(:bedrock_credential_provider).and_return(credentials_provider)
      end

      it 'only requires bedrock_region' do
        expect(provider.send(:configuration_requirements)).to eq(%i[bedrock_region])
      end
    end

    context 'without credential provider' do
      before do
        allow(config).to receive_messages(
          bedrock_api_key: 'test-key',
          bedrock_secret_key: 'test-secret'
        )
      end

      it 'requires static credentials and region' do
        expect(provider.send(:configuration_requirements)).to eq(%i[bedrock_api_key bedrock_secret_key bedrock_region])
      end
    end
  end
end
