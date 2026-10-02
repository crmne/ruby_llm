# frozen_string_literal: true

require 'spec_helper'
require 'aws-eventstream'

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

  describe '#parse_error' do
    let(:provider) do
      described_class.new(bedrock_config(api_key: 'static-key', secret_key: 'static-secret'))
    end

    it 'falls back to the generic parser for list-shaped errors' do
      response = instance_double(Faraday::Response, body: [{ 'message' => 'first' }, 'second'])

      expect(provider.parse_error(response)).to eq('first. second')
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
          .to eq(described_class.protocols.fetch(:titan_text_embeddings))
      end
    end

    it 'routes Titan multimodal embedding models to the Titan multimodal embedding protocol' do
      model = instance_double(RubyLLM::Model, id: 'amazon.titan-embed-image-v1')

      expect(provider.protocol_for(model, operation: :embed))
        .to eq(described_class.protocols.fetch(:titan_multimodal_embeddings))
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

      expect(provider.protocol_for(model)).to eq(provider.protocols[:converse])
    end

    it 'routes un-versioned anthropic ids to Mantle' do
      model = instance_double(RubyLLM::Model, id: 'anthropic.claude-opus-5')

      expect(provider.protocol_for(model)).to eq(RubyLLM::Providers::Bedrock::Mantle::Anthropic)
    end

    it 'routes un-versioned non-anthropic ids to Mantle Responses' do
      model = instance_double(RubyLLM::Model, id: 'openai.gpt-oss-20b')

      expect(provider.protocol_for(model)).to eq(RubyLLM::Providers::Bedrock::Mantle::Responses)
    end

    it 'keeps regional Sonnet 5.5 ids on Mantle Anthropic when Mantle serves them' do
      expect(provider.send(:mantle_protocol_for, 'us.anthropic.claude-sonnet-5-5'))
        .to eq(provider.protocols[:mantle_anthropic])
      expect(provider.send(:mantle_protocol_for, 'global.anthropic.claude-sonnet-5-5'))
        .to eq(provider.protocols[:mantle_anthropic])
    end

    it 'keeps regional Sonnet 5.5 chat routing on Converse' do
      model = instance_double(RubyLLM::Model, id: 'us.anthropic.claude-sonnet-5-5')

      expect(provider.protocol_for(model)).to eq(provider.protocols[:converse])
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

    it 'sorts repeated parameters by their encoded values' do
      expect(signer.send(:canonical_query_string, 'tag=z&tag=a&name=ruby')).to eq('name=ruby&tag=a&tag=z')
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

    it 'signs a GET and decodes its JSON response' do
      request = stub_request(:get, 'https://bedrock.us-east-1.amazonaws.com/foundation-models')
                .with(headers: { 'Authorization' => /\AAWS4-HMAC-SHA256 Credential=key/ })
                .to_return(body: '{"modelSummaries":[]}', headers: { 'Content-Type' => 'application/json' })

      response = provider.signed_get('https://bedrock.us-east-1.amazonaws.com', '/foundation-models')

      expect(response.body).to eq('modelSummaries' => [])
      expect(request).to have_been_requested
    end

    it 'signs a POST over the serialized payload and decodes its JSON response' do
      body = '{"key":"value"}'
      request = stub_request(:post, 'https://bedrock.us-east-1.amazonaws.com/batch')
                .with(body: body, headers: {
                        'Authorization' => /\AAWS4-HMAC-SHA256 Credential=key/,
                        'Content-Type' => 'application/json',
                        'X-Amz-Content-Sha256' => Digest::SHA256.hexdigest(body)
                      })
                .to_return(body: '{"status":"Submitted"}', headers: { 'Content-Type' => 'application/json' })

      response = provider.signed_post('https://bedrock.us-east-1.amazonaws.com', '/batch', { key: 'value' })

      expect(response.body).to eq('status' => 'Submitted')
      expect(request).to have_been_requested
    end

    it 'serializes a chat request once and sends the bytes it signed' do
      context = RubyLLM.context do |config|
        config.bedrock_api_key = 'key'
        config.bedrock_secret_key = 'secret'
        config.bedrock_region = 'us-east-1'
      end
      reply = { output: { message: { role: 'assistant', content: [{ text: 'Hi' }] } },
                stopReason: 'end_turn', usage: { inputTokens: 3, outputTokens: 1 } }.to_json
      request = stub_request(:post, %r{\Ahttps://bedrock-runtime\.us-east-1\.amazonaws\.com/model/.+/converse\z})
                .with { |req| req.headers['X-Amz-Content-Sha256'] == Digest::SHA256.hexdigest(req.body) }
                .to_return(body: reply, headers: { 'Content-Type' => 'application/json' })
      allow(JSON).to receive(:generate).and_call_original

      context.chat(model: 'amazon.nova-2-lite-v1:0', provider: :bedrock).ask('Hello')

      expect(request).to have_been_requested
      expect(JSON).to have_received(:generate).once
    end
  end

  describe 'retried requests' do
    let(:context) do
      RubyLLM.context do |config|
        config.bedrock_api_key = 'key'
        config.bedrock_secret_key = 'secret'
        config.bedrock_region = 'us-east-1'
        config.max_retries = 1
        config.retry_interval = 0
        config.retry_interval_randomness = 0
      end
    end
    let(:clock) { { now: Time.utc(2026, 10, 2, 14, 12, 2) } }
    let(:attempts) { [] }

    before { allow(Time).to receive(:now) { clock[:now] } }

    def runtime
      'https://bedrock-runtime.us-east-1.amazonaws.com'
    end

    def provider
      described_class.new(context.config)
    end

    def json_reply(body)
      { status: 200, headers: { 'Content-Type' => 'application/json' }, body: body.to_json }
    end

    def converse_reply
      json_reply(output: { message: { role: 'assistant', content: [{ text: 'Hi' }] } },
                 stopReason: 'end_turn', usage: { inputTokens: 3, outputTokens: 1 })
    end

    # The first attempt times out once SigV4's five-minute window has passed.
    def time_out_once_then(response)
      lambda do |request|
        attempts << request
        return response if attempts.size > 1

        clock[:now] += 360
        raise Net::ReadTimeout
      end
    end

    def signature(method, path, body, **)
      provider.sign_headers(method, path, body.to_s, **)['Authorization']
    end

    def amz_dates
      attempts.map { |attempt| attempt.headers['X-Amz-Date'] }
    end

    def event(type, payload)
      Aws::EventStream::Encoder.new.encode_message(
        Aws::EventStream::Message.new(
          headers: { ':event-type' => Aws::EventStream::HeaderValue.new(value: type, type: 'string'),
                     ':message-type' => Aws::EventStream::HeaderValue.new(value: 'event', type: 'string') },
          payload: StringIO.new(payload.to_json)
        )
      )
    end

    it 'signs a chat retry when it is sent, over the body it sends' do
      chat = context.chat(model: model_for(:bedrock), provider: :bedrock)
      path = "/model/#{chat.model.id}/converse"
      stub_request(:post, "#{runtime}#{path}").to_return(time_out_once_then(converse_reply))

      expect(chat.ask('Hello').content).to eq('Hi')

      expect(amz_dates).to eq(%w[20261002T141202Z 20261002T141802Z])
      expect(attempts.last.headers['Authorization']).to eq(signature('POST', path, attempts.last.body))
      expect(attempts.first.headers['Authorization']).not_to eq(attempts.last.headers['Authorization'])
    end

    it 'signs a converse-stream retry when it is sent' do
      chat = context.chat(model: model_for(:bedrock), provider: :bedrock)
      path = "/model/#{chat.model.id}/converse-stream"
      events = [event('contentBlockDelta', { contentBlockIndex: 0, delta: { text: 'Hi' } }),
                event('messageStop', { stopReason: 'end_turn' }),
                event('metadata', { usage: { inputTokens: 3, outputTokens: 1 } })].join
      stub_request(:post, "#{runtime}#{path}").to_return(
        time_out_once_then(status: 200, body: events,
                           headers: { 'Content-Type' => 'application/vnd.amazon.eventstream' })
      )

      chunks = []
      chat.ask('Hello') { |chunk| chunks << chunk.content }

      expect(chunks.join).to eq('Hi')
      expect(amz_dates).to eq(%w[20261002T141202Z 20261002T141802Z])
      expect(attempts.last.headers['Authorization']).to eq(signature('POST', path, attempts.last.body))
    end

    it 'signs a count-tokens retry when it is sent' do
      chat = context.chat(model: model_for(:bedrock), provider: :bedrock)
      path = "/model/#{chat.model.id}/count-tokens"
      stub_request(:post, "#{runtime}#{path}").to_return(time_out_once_then(json_reply(inputTokens: 7)))

      expect(chat.count_tokens('Hello')).to eq(7)

      expect(amz_dates).to eq(%w[20261002T141202Z 20261002T141802Z])
      expect(attempts.last.headers['Authorization']).to eq(signature('POST', path, attempts.last.body))
    end

    it 'drops a session token the retry is no longer signed with' do
      sts = credentials(access_key_id: 'key', secret_access_key: 'secret', session_token: 'sts-token')
      static = credentials(access_key_id: 'key', secret_access_key: 'secret', session_token: nil)
      recorded = attempts
      provider = Object.new
      provider.define_singleton_method(:credentials) { recorded.empty? ? sts : static }
      context.config.bedrock_credential_provider = provider
      chat = context.chat(model: model_for(:bedrock), provider: :bedrock)
      stub_request(:post, "#{runtime}/model/#{chat.model.id}/converse").to_return(time_out_once_then(converse_reply))

      chat.ask('Hello')

      expect(attempts.map { |attempt| attempt.headers['X-Amz-Security-Token'] }).to eq(['sts-token', nil])
      expect(attempts.last.headers['Authorization']).to include('SignedHeaders=host;x-amz-content-sha256;x-amz-date,')
    end

    it 'signs an escaped inference profile ARN path the way the request sends it' do
      arn = 'arn:aws:bedrock:us-east-1:123456789012:application-inference-profile/abc123'
      path = "/model/#{arn.gsub('/', '%2F')}/converse"
      stub_request(:post, "#{runtime}#{path}").to_return(time_out_once_then(converse_reply))

      context.chat(model: arn, provider: :bedrock, assume_model_exists: true).ask('Hello')

      expect(amz_dates).to eq(%w[20261002T141202Z 20261002T141802Z])
      expect(attempts.last.headers['Authorization']).to eq(signature('POST', path, attempts.last.body))
    end

    it 'signs a mantle retry for the bedrock-mantle service' do
      reply = json_reply(id: 'msg_1', type: 'message', role: 'assistant', model: 'anthropic.claude-sonnet-5',
                         content: [{ type: 'text', text: 'Hi' }], stop_reason: 'end_turn',
                         usage: { input_tokens: 3, output_tokens: 1 })
      stub_request(:post, "#{provider.mantle_api_base}/anthropic/v1/messages").to_return(time_out_once_then(reply))

      context.chat(model: 'anthropic.claude-sonnet-5', provider: :bedrock).ask('Hello')

      expect(amz_dates).to eq(%w[20261002T141202Z 20261002T141802Z])
      expect(attempts.last.headers['Authorization']).to eq(
        signature('POST', '/anthropic/v1/messages', attempts.last.body,
                  base_url: provider.mantle_api_base, service: 'bedrock-mantle')
      )
      expect(attempts.last.headers['Anthropic-Version']).to eq('2023-06-01')
    end

    it 'signs a video status retry when it is sent' do
      job_id = 'arn:aws:bedrock:us-east-1:123456789012:async-invoke/abc123'
      path = "/async-invoke/#{URI.encode_www_form_component(job_id)}"
      stub_request(:get, "#{runtime}#{path}").to_return(time_out_once_then(json_reply(status: 'InProgress')))
      model = RubyLLM.models.find(model_for(:bedrock, :bedrock_video), provider: :bedrock)
      protocol = RubyLLM::Protocols::Bedrock::AsyncVideos.new(provider, model)

      expect(RubyLLM::VideoJob.new(id: job_id, protocol:, model: model.id).refresh).to be_pending

      expect(amz_dates).to eq(%w[20261002T141202Z 20261002T141802Z])
      expect(attempts.last.headers['Authorization']).to eq(signature('GET', path, ''))
    end
  end
end
