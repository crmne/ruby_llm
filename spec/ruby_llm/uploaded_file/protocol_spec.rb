# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::UploadedFile::Protocol do
  let(:fixture_path) { File.expand_path('../../fixtures/ruby.txt', __dir__) }

  describe RubyLLM::Protocols::OpenAI::Files do
    let(:provider) do
      RubyLLM::Providers::OpenAI.new(RubyLLM::Configuration.new.tap { |config| config.openai_api_key = 'test' })
    end
    let(:protocol) { described_class.new(provider) }

    it 'builds an upload payload from a path' do
      payload = protocol.send(:render_upload_payload, RubyLLM::Attachment.new(fixture_path), purpose: 'batch')

      expect(payload.fetch(:purpose)).to eq('batch')
      expect(payload.fetch(:file).original_filename).to eq('ruby.txt')
      expect(payload.fetch(:file).local_path).to eq(fixture_path)
    end

    it 'requires a purpose' do
      expect { protocol.send(:render_upload_payload, RubyLLM::Attachment.new(fixture_path)) }
        .to raise_error(
          ArgumentError,
          'OpenAI file uploads require purpose: assistants, batch, fine-tune, vision, user_data, evals'
        )
    end

    it 'normalizes file metadata' do
      file = protocol.send(:parse_file_response, {
                             'id' => 'file_123',
                             'filename' => 'batch.jsonl',
                             'bytes' => 123,
                             'created_at' => 1_700_000_000,
                             'expires_at' => 1_700_086_400,
                             'status' => 'processed',
                             'purpose' => 'batch'
                           })

      expect(file).to have_attributes(
        id: 'file_123',
        filename: 'batch.jsonl',
        byte_size: 123,
        created_at: Time.at(1_700_000_000),
        expires_at: Time.at(1_700_086_400),
        status: 'processed',
        purpose: 'batch'
      )
    end
  end

  describe RubyLLM::Providers::Azure::Files do
    it 'uses Azure OpenAI v1 files endpoints' do
      config = RubyLLM::Configuration.new.tap do |config|
        config.azure_api_base = 'https://example.openai.azure.com'
        config.azure_api_key = 'test'
      end
      protocol = described_class.new(RubyLLM::Providers::Azure.new(config))

      expect(protocol.send(:files_url)).to eq('https://example.openai.azure.com/openai/v1/files')
    end
  end

  describe RubyLLM::Providers::Mistral::Files do
    let(:provider) do
      RubyLLM::Providers::Mistral.new(RubyLLM::Configuration.new.tap { |config| config.mistral_api_key = 'test' })
    end
    let(:protocol) { described_class.new(provider) }

    it 'accepts purpose without requiring it' do
      payload = protocol.send(:render_upload_payload, RubyLLM::Attachment.new(fixture_path), purpose: 'batch')

      expect(payload.fetch(:purpose)).to eq('batch')
      expect(payload.fetch(:file).original_filename).to eq('ruby.txt')
    end
  end

  describe RubyLLM::Providers::XAI::Files do
    let(:provider) do
      RubyLLM::Providers::XAI.new(RubyLLM::Configuration.new.tap { |config| config.xai_api_key = 'test' })
    end
    let(:protocol) { described_class.new(provider) }

    it 'does not require purpose' do
      payload = protocol.send(:render_upload_payload, RubyLLM::Attachment.new(fixture_path))

      expect(payload).to have_key(:file)
      expect(payload).not_to have_key(:purpose)
    end
  end

  describe RubyLLM::Protocols::Anthropic::Files do
    let(:provider) do
      RubyLLM::Providers::Anthropic.new(RubyLLM::Configuration.new.tap { |config| config.anthropic_api_key = 'test' })
    end
    let(:protocol) { described_class.new(provider) }

    it 'adds the beta header' do
      request = Struct.new(:headers).new({})

      protocol.send(:file_headers, request)

      expect(request.headers.fetch('anthropic-beta')).to eq('files-api-2025-04-14')
    end

    it 'normalizes ISO timestamps' do
      file = protocol.send(:parse_file_response, {
                             'id' => 'file_123',
                             'filename' => 'document.pdf',
                             'mime_type' => 'application/pdf',
                             'size_bytes' => 1024,
                             'created_at' => '2025-01-01T00:00:00Z',
                             'downloadable' => false
                           })

      expect(file).to have_attributes(
        id: 'file_123',
        filename: 'document.pdf',
        mime_type: 'application/pdf',
        byte_size: 1024,
        created_at: Time.iso8601('2025-01-01T00:00:00Z'),
        downloadable: false
      )
    end
  end

  describe RubyLLM::Protocols::Gemini::Files do
    let(:provider) do
      config = RubyLLM::Configuration.new.tap do |config|
        config.gemini_api_key = 'test'
        config.faraday_adapter = :net_http
      end
      RubyLLM::Providers::Gemini.new(config)
    end
    let(:protocol) { described_class.new(provider) }

    it 'normalizes file metadata' do
      file = protocol.send(:parse_file_response, {
                             'name' => 'files/abc',
                             'displayName' => 'video.mp4',
                             'sizeBytes' => '2048',
                             'mimeType' => 'video/mp4',
                             'state' => 'ACTIVE',
                             'createTime' => '2025-01-01T00:00:00Z',
                             'expirationTime' => '2025-01-03T00:00:00Z',
                             'uri' => 'https://generativelanguage.googleapis.com/v1beta/files/abc'
                           })

      expect(file).to have_attributes(
        id: 'files/abc',
        filename: 'video.mp4',
        byte_size: 2048,
        mime_type: 'video/mp4',
        status: 'ACTIVE',
        uri: 'https://generativelanguage.googleapis.com/v1beta/files/abc'
      )
    end
  end

  describe RubyLLM::Providers::Bedrock::Files do
    let(:config) do
      instance_double(
        RubyLLM::Configuration,
        bedrock_api_key: 'key',
        bedrock_secret_key: 'secret',
        bedrock_session_token: nil,
        bedrock_region: 'us-west-2',
        bedrock_batch_s3_uri: 's3://ruby-llm-batches/test'
      )
    end
    let(:provider) { instance_double(RubyLLM::Providers::Bedrock, config: config, connection: nil, slug: 'bedrock') }
    let(:protocol) { described_class.new(provider) }

    it 'uploads through aws-sdk-s3' do
      client = Class.new do
        attr_reader :put_options

        def put_object(**options)
          @put_options = options
        end
      end.new
      allow(protocol).to receive(:s3_client).and_return(client)

      file = protocol.upload(StringIO.new("{\"hello\":\"world\"}\n"),
                             uri: 's3://bucket/path/input.jsonl',
                             filename: 'input.jsonl',
                             content_type: 'application/jsonl')

      expect(file).to have_attributes(id: 's3://bucket/path/input.jsonl', uri: 's3://bucket/path/input.jsonl')
      expect(client.put_options).to include(
        bucket: 'bucket',
        key: 'path/input.jsonl',
        content_type: 'application/jsonl'
      )
      expect(client.put_options.fetch(:body)).to be_a(StringIO)
    end

    it 'lazy-loads the optional gem' do
      allow(protocol).to receive(:require).with('aws-sdk-s3').and_raise(LoadError)

      expect { protocol.send(:s3_client) }.to raise_error(RubyLLM::Error, /aws-sdk-s3/)
    end
  end

  describe RubyLLM::Providers::VertexAI::Files do
    let(:config) do
      instance_double(
        RubyLLM::Configuration,
        vertexai_project_id: 'project',
        vertexai_service_account_key: nil,
        vertexai_batch_gcs_uri: 'gs://ruby-llm-batches/test'
      )
    end
    let(:provider) { instance_double(RubyLLM::Providers::VertexAI, config: config, connection: nil, slug: 'vertexai') }
    let(:protocol) { described_class.new(provider) }

    it 'uploads through google-cloud-storage' do
      bucket = Class.new do
        attr_reader :create_file_args

        def create_file(*args, **options)
          @create_file_args = [args, options]
        end
      end.new
      allow(protocol).to receive(:bucket).with('bucket').and_return(bucket)

      file = protocol.upload(StringIO.new("{\"hello\":\"world\"}\n"),
                             uri: 'gs://bucket/path/input.jsonl',
                             filename: 'input.jsonl',
                             content_type: 'application/jsonl')

      expect(file).to have_attributes(id: 'gs://bucket/path/input.jsonl', uri: 'gs://bucket/path/input.jsonl')
      expect(bucket.create_file_args).to match(
        [[kind_of(StringIO), 'path/input.jsonl'], { content_type: 'application/jsonl' }]
      )
    end

    it 'lazy-loads the optional gem' do
      allow(protocol).to receive(:require).with('google/cloud/storage').and_raise(LoadError)

      expect { protocol.send(:storage) }.to raise_error(RubyLLM::Error, /google-cloud-storage/)
    end
  end
end
