# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'upload provider_options' do # rubocop:disable RSpec/DescribeClass
  let(:fixture_path) { File.expand_path('../../fixtures/ruby.txt', __dir__) }

  def context_for(slug)
    RubyLLM.context do |config|
      config.public_send(:"#{slug}_api_key=", 'test')
      config.azure_api_base = 'https://example.openai.azure.com' if slug == :azure
    end
  end

  def field_names(body)
    body.scan(/(?<!file)name="([^"]+)"/).flatten
  end

  {
    openai: 'https://api.openai.com/v1/files',
    azure: %r{\Ahttps://example\.openai\.azure\.com/.*/files},
    anthropic: 'https://api.anthropic.com/v1/files',
    mistral: 'https://api.mistral.ai/v1/files',
    xai: 'https://api.x.ai/v1/files',
    deepseek: 'https://api.deepseek.com/files',
    openrouter: 'https://openrouter.ai/api/v1/files'
  }.each do |slug, url|
    context "with #{slug}" do
      def uploaded_body(slug, url, provider_options)
        body = nil
        stub_request(:post, url).with { |request| body = request.body }
                                .to_return_json(body: { id: 'file_1', filename: 'ruby.txt' })
        RubyLLM.upload(fixture_path, provider: slug, context: context_for(slug), provider_options:)
        body
      end

      it 'sends an unknown option in the form, before the file' do
        names = field_names(uploaded_body(slug, url, { 'anything' => 1 }))

        expect(names).to include('anything')
        expect(names.last).to eq('file')
      end

      it 'never lets an option replace the file part' do
        body = uploaded_body(slug, url, { file: 'replaced' })

        expect(field_names(body).count('file')).to eq(1)
        expect(body).not_to include('replaced')
        expect(body).to include(File.read(fixture_path))
      end
    end
  end

  it 'lets Mistral visibility through in its own vocabulary' do
    request = stub_request(:post, 'https://api.mistral.ai/v1/files')
              .with { |req| req.body.include?('name="visibility"') }
              .to_return_json(body: { id: 'file_1', filename: 'ruby.txt' })

    RubyLLM.upload(fixture_path, provider: :mistral, context: context_for(:mistral),
                                 provider_options: { visibility: 'workspace' })

    expect(request).to have_been_requested
  end

  it 'puts xAI expires_after before the file' do
    request = stub_request(:post, 'https://api.x.ai/v1/files')
              .with { |req| field_names(req.body) == %w[expires_after file] }
              .to_return_json(body: { id: 'file_1', filename: 'ruby.txt' })

    RubyLLM.upload(fixture_path, provider: :xai, context: context_for(:xai), expires_in: 3600)

    expect(request).to have_been_requested
  end

  it 'turns Anthropic expires_in into expires_in_seconds and reads the expiry back' do
    request = stub_request(:post, 'https://api.anthropic.com/v1/files')
              .with { |req| req.body.include?(%(name="expires_in_seconds"\r\n\r\n3600\r\n)) }
              .to_return_json(body: { id: 'file_1', filename: 'ruby.txt',
                                      expires_at: '2026-11-02T10:00:00Z' })

    file = RubyLLM.upload(fixture_path, provider: :anthropic, context: context_for(:anthropic), expires_in: 3600)

    expect(request).to have_been_requested
    expect(file.expires_at).to eq(Time.iso8601('2026-11-02T10:00:00Z'))
  end

  describe 'ElevenLabs assets' do
    let(:provider) { RubyLLM::Providers::ElevenLabs.new(context_for(:elevenlabs).config) }
    let(:protocol) { RubyLLM::Protocols::ElevenLabs::Assets.new(provider) }

    it 'sends options in the form and keeps the asset part' do
      request = stub_request(:post, 'https://api.elevenlabs.io/v1/assets')
                .with { |req| field_names(req.body) == %w[name anything asset] }
                .to_return_json(body: { asset_id: 'asset_1', name: 'ruby.txt' })

      protocol.upload(fixture_path, provider_options: { anything: 1, asset: 'replaced' })

      expect(request).to have_been_requested
    end

    it 'names the asset after the option when given' do
      payload = protocol.send(:render_upload_payload, RubyLLM::Attachment.new(fixture_path),
                              provider_options: { name: 'renamed' })

      expect(payload.fetch(:name)).to eq('renamed')
    end
  end

  describe 'Gemini' do
    let(:provider) { RubyLLM::Providers::Gemini.new(context_for(:gemini).config) }

    it 'sends options on the File resource, whatever their key type' do
      start = stub_request(:post, 'https://generativelanguage.googleapis.com/upload/v1beta/files')
              .with(body: { file: { display_name: 'shown', name: 'files/x' } }.to_json)
              .to_return(headers: { 'X-Goog-Upload-URL' => 'https://upload.example/session' })
      stub_request(:post, 'https://upload.example/session')
        .to_return(body: '{"file":{"name":"files/x","state":"ACTIVE"}}',
                   headers: { 'Content-Type' => 'application/json' })

      RubyLLM::Protocols::Gemini::Files.new(provider)
                                       .upload(fixture_path, provider_options: { 'display_name' => 'shown',
                                                                                 name: 'files/x' })

      expect(start).to have_been_requested
    end
  end

  describe 'Bedrock' do
    let(:config) { instance_double(RubyLLM::Configuration, bedrock_batch_s3_uri: 's3://bucket/test') }
    let(:provider) { instance_double(RubyLLM::Providers::Bedrock, config: config, connection: nil, slug: 'bedrock') }
    let(:protocol) { RubyLLM::Protocols::Bedrock::Files.new(provider) }
    let(:client) do
      Class.new do
        attr_reader :options

        def put_object(**options)
          @options = options
        end
      end.new
    end

    before { allow(protocol).to receive(:s3_client).and_return(client) }

    it 'passes options to PutObject without touching the object itself' do
      protocol.upload(fixture_path, uri: 's3://bucket/a.txt',
                                    provider_options: { 'storage_class' => 'STANDARD_IA', bucket: 'b', key: 'k',
                                                        body: 'replaced' })

      expect(client.options).to include(storage_class: 'STANDARD_IA', bucket: 'bucket', key: 'a.txt',
                                        body: kind_of(File))
    end
  end

  describe 'Vertex AI' do
    let(:config) { instance_double(RubyLLM::Configuration, vertexai_batch_gcs_uri: 'gs://bucket/test') }
    let(:provider) { instance_double(RubyLLM::Providers::VertexAI, config: config, connection: nil, slug: 'vertexai') }
    let(:protocol) { RubyLLM::Protocols::VertexAI::Files.new(provider) }
    let(:bucket) do
      Class.new do
        attr_reader :arguments

        def create_file(*args, **options)
          @arguments = [args, options]
        end
      end.new
    end

    it 'passes options to create_file' do
      allow(protocol).to receive(:bucket).with('bucket').and_return(bucket)

      protocol.upload(fixture_path, uri: 'gs://bucket/a.txt', provider_options: { 'cache_control' => 'no-store' })

      expect(bucket.arguments).to match([[kind_of(File), 'a.txt'], hash_including(cache_control: 'no-store')])
    end
  end
end
