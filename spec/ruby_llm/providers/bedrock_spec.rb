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

  describe '#protocol_for' do
    let(:provider) do
      described_class.new(bedrock_config(api_key: 'static-key', secret_key: 'static-secret'))
    end

    it 'routes Titan text embedding models to the Titan text embedding protocol' do
      %w[
        amazon.titan-embed-g1-text-02
        amazon.titan-embed-text-v1
        amazon.titan-embed-text-v2:0
      ].each do |id|
        model = instance_double(RubyLLM::Model, id: id)

        expect(provider.protocol_for(model, operation: :embed))
          .to eq(RubyLLM::Protocols::InvokeModel::TitanTextEmbeddings)
      end
    end

    it 'routes Titan multimodal embedding models to the Titan multimodal embedding protocol' do
      model = instance_double(RubyLLM::Model, id: 'amazon.titan-embed-image-v1')

      expect(provider.protocol_for(model, operation: :embed))
        .to eq(RubyLLM::Protocols::InvokeModel::TitanMultimodalEmbeddings)
    end

    it 'routes Cohere embedding models to the Cohere embedding protocol' do
      %w[cohere.embed-english-v3 us.cohere.embed-v4:0].each do |id|
        model = instance_double(RubyLLM::Model, id: id)

        expect(provider.protocol_for(model, operation: :embed))
          .to eq(RubyLLM::Protocols::InvokeModel::CohereEmbeddings)
      end
    end

    it 'routes Nova multimodal embedding models to the Nova embedding protocol' do
      %w[amazon.nova-2-multimodal-embeddings-v1:0 us.amazon.nova-2-multimodal-embeddings-v1:0].each do |id|
        model = instance_double(RubyLLM::Model, id: id)

        expect(provider.protocol_for(model, operation: :embed))
          .to eq(RubyLLM::Protocols::InvokeModel::NovaEmbeddings)
      end
    end

    it 'raises clearly for unsupported Bedrock embedding models' do
      model = instance_double(RubyLLM::Model, id: 'vendor.unknown-embed')

      expect { provider.protocol_for(model, operation: :embed) }
        .to raise_error(RubyLLM::Error, /Bedrock embeddings are not supported/)
    end

    it 'keeps chat routing on Converse for versioned ids' do
      model = instance_double(RubyLLM::Model, id: 'anthropic.claude-3-5-haiku-20241022-v1:0')

      expect(provider.protocol_for(model)).to eq(RubyLLM::Protocols::Converse)
    end

    it 'routes un-versioned anthropic ids to Mantle' do
      model = instance_double(RubyLLM::Model, id: 'anthropic.claude-opus-5')

      expect(provider.protocol_for(model)).to eq(RubyLLM::Providers::Bedrock::Mantle::Anthropic)
    end

    it 'routes un-versioned non-anthropic ids to Mantle Responses' do
      model = instance_double(RubyLLM::Model, id: 'openai.gpt-oss-20b')

      expect(provider.protocol_for(model)).to eq(RubyLLM::Providers::Bedrock::Mantle::Responses)
    end
  end

  describe 'model id path encoding' do
    let(:converse) { RubyLLM::Protocols::Converse.allocate }
    let(:arn) { 'arn:aws:bedrock:us-west-2:123:application-inference-profile/p' }

    def with_model(id)
      converse.instance_variable_set(:@model, instance_double(RubyLLM::Model, id: id))
    end

    it 'keeps an application inference profile ARN as a single path segment in the converse URL' do
      with_model(arn)
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
      expect(described_class.allocate.send(:canonical_uri, path)).to eq(
        '/model/arn%3Aaws%3Abedrock%3Aus-west-2%3A123%3Aapplication-inference-profile%252Fp/converse'
      )
    end
  end

  describe 'SigV4 canonicalization' do
    let(:signer) { described_class.allocate }

    it 'sorts and encodes the query string' do
      expect(signer.send(:canonical_query_string, 'b=2&a=1&c=hello world')).to eq('a=1&b=2&c=hello%20world')
    end

    it 'treats a missing query string as empty' do
      expect(signer.send(:canonical_query_string, nil)).to eq('')
      expect(signer.send(:canonical_query_string, '')).to eq('')
    end

    it 'treats a missing path as the root' do
      expect(signer.send(:canonical_uri, nil)).to eq('/')
      expect(signer.send(:canonical_uri, '')).to eq('/')
    end

    it 'prefixes a relative path with a slash' do
      expect(signer.send(:canonical_uri, 'foundation-models')).to eq('/foundation-models')
    end

    it 'leaves the unreserved tilde unescaped' do
      expect(signer.send(:uri_encode, 'a~b c')).to eq('a~b%20c')
    end
  end

  describe 'signed requests' do
    let(:provider) { described_class.new(bedrock_config(api_key: 'key', secret_key: 'secret')) }

    it 'signs a GET through a bare connection' do
      connection = instance_double(Faraday::Connection)
      allow(connection).to receive(:url_prefix=)
      allow(RubyLLM::Connection).to receive(:basic).and_return(connection)
      headers = {}
      allow(connection).to receive(:get) do |url, _payload, &block|
        request = Struct.new(:headers).new(headers)
        block.call(request)
        expect(url).to eq('/foundation-models')
        Struct.new(:body).new({})
      end

      provider.send(:signed_get, 'https://bedrock.us-east-1.amazonaws.com', '/foundation-models')

      expect(headers['Authorization']).to match(/\AAWS4-HMAC-SHA256 Credential=key/)
      expect(connection).to have_received(:url_prefix=).with('https://bedrock.us-east-1.amazonaws.com')
    end

    it 'signs a POST over the serialized payload' do
      connection = instance_double(Faraday::Connection)
      allow(connection).to receive(:url_prefix=)
      allow(RubyLLM::Connection).to receive(:basic).and_return(connection)
      captured = {}
      allow(connection).to receive(:post) do |_url, payload, &block|
        request = Struct.new(:headers).new({})
        block.call(request)
        captured[:payload] = payload
        captured[:headers] = request.headers
        Struct.new(:body).new({})
      end

      provider.send(:signed_post, 'https://bedrock.us-east-1.amazonaws.com', '/batch', { key: 'value' })

      expect(captured[:payload]).to eq(key: 'value')
      expect(captured[:headers]['Content-Type']).to eq('application/json')
    end
  end
end
