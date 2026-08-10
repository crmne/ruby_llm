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
      expect(payload).not_to have_key(:expires_after)
    end

    it 'translates expires_in to the anchored expires_after shape' do
      payload = protocol.send(:render_upload_payload, RubyLLM::Attachment.new(fixture_path),
                              purpose: 'batch', expires_in: 3600)

      expect(payload.fetch(:expires_after)).to eq(anchor: 'created_at', seconds: 3600)
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
        provider: 'openai',
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
      expect(payload).not_to have_key(:expiry)
    end

    it 'translates expires_in to whole expiry hours, rounding up' do
      payload = protocol.send(:render_upload_payload, RubyLLM::Attachment.new(fixture_path),
                              purpose: 'batch', expires_in: 5400)

      expect(payload.fetch(:expiry)).to eq(2)
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
      expect(payload).not_to have_key(:expires_after)
    end

    it 'passes expires_in as expires_after seconds' do
      payload = protocol.send(:render_upload_payload, RubyLLM::Attachment.new(fixture_path), expires_in: 3600)

      expect(payload.fetch(:expires_after)).to eq(3600)
    end
  end

  describe RubyLLM::Providers::OpenRouter::Files do
    let(:provider) do
      RubyLLM::Providers::OpenRouter.new(
        RubyLLM::Configuration.new.tap { |config| config.openrouter_api_key = 'test' }
      )
    end
    let(:protocol) { described_class.new(provider) }

    it 'normalizes file metadata' do
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
        provider: 'openrouter',
        filename: 'document.pdf',
        byte_size: 1024,
        mime_type: 'application/pdf',
        downloadable: false
      )
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

    it 'prefixes a bare file id with the collection name' do
      expect(protocol.send(:file_info_url, 'abc')).to eq('files/abc')
      expect(protocol.send(:file_info_url, 'files/abc')).to eq('files/abc')
    end

    it 'points uploads at the resumable upload host' do
      expect(protocol.send(:gemini_upload_url)).to eq(
        'https://generativelanguage.googleapis.com/upload/v1beta/files'
      )
    end

    it 'uploads in two steps and returns the stored file' do
      connection = instance_double(Faraday::Connection)
      allow(RubyLLM::Connection).to receive(:basic).and_return(connection)
      allow(connection).to receive(:url_prefix=)
      allow(connection).to receive(:post) do |url, &block|
        request = Struct.new(:headers, :body, keyword_init: false).new({}, nil)
        block.call(request)
        if url == protocol.send(:gemini_upload_url)
          Struct.new(:headers, :body).new({ 'x-goog-upload-url' => 'https://upload.example/session' }, {})
        else
          Struct.new(:headers, :body).new({}, { 'file' => { 'name' => 'files/abc', 'displayName' => 'ruby.txt' } })
        end
      end

      file = protocol.upload(fixture_path)

      expect(file.id).to eq('files/abc')
      expect(file.filename).to eq('ruby.txt')
    end

    it 'raises when Gemini does not hand back an upload URL' do
      connection = instance_double(Faraday::Connection)
      allow(RubyLLM::Connection).to receive(:basic).and_return(connection)
      allow(connection).to receive(:url_prefix=)
      allow(connection).to receive(:post) do |_url, &block|
        block.call(Struct.new(:headers, :body).new({}, nil))
        Struct.new(:headers, :body).new({}, {})
      end

      expect { protocol.upload(fixture_path) }.to raise_error(RubyLLM::Error, 'gemini did not return an upload URL')
    end

    it 'refuses to download a file with no download URI' do
      allow(protocol).to receive(:find).and_return(
        RubyLLM::UploadedFile.new(id: 'files/abc', provider: 'gemini', metadata: {})
      )

      expect { protocol.download('files/abc') }.to raise_error(RubyLLM::Error, 'gemini file has no download URI')
    end

    it 'downloads the bytes from the URI the file carries' do
      allow(protocol).to receive(:find).and_return(
        RubyLLM::UploadedFile.new(
          id: 'files/abc', provider: 'gemini', metadata: { 'downloadUri' => 'https://files.example/abc' }
        )
      )
      connection = instance_double(Faraday::Connection)
      allow(RubyLLM::Connection).to receive(:basic).and_return(connection)
      allow(connection).to receive(:url_prefix=)
      allow(connection).to receive(:get) do |_url, &block|
        block.call(Struct.new(:headers).new({}))
        Struct.new(:body).new('bytes')
      end

      expect(protocol.download('files/abc')).to eq('bytes')
    end
  end

  describe RubyLLM::Providers::Bedrock::Files do
    let(:config) do
      instance_double(
        RubyLLM::Configuration,
        bedrock_api_key: 'key',
        bedrock_secret_key: 'secret',
        bedrock_session_token: nil,
        bedrock_credential_provider: nil,
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

    it 'passes credential providers to aws-sdk-s3' do
      credential_provider = Object.new
      allow(config).to receive(:bedrock_credential_provider).and_return(credential_provider)

      expect(protocol.send(:s3_client_options)).to eq(
        region: 'us-west-2',
        credentials: credential_provider
      )
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

  describe 'the shared protocol' do
    let(:provider) do
      RubyLLM::Providers::OpenAI.new(RubyLLM::Configuration.new.tap { |config| config.openai_api_key = 'test' })
    end
    let(:protocol) { RubyLLM::Protocols::OpenAI::Files.new(provider) }
    let(:connection) { instance_double(RubyLLM::Connection) }

    before { protocol.instance_variable_set(:@connection, connection) }

    it 'finds a file by id' do
      allow(connection).to receive(:get).with('files/file_123').and_return(
        Struct.new(:body).new({ 'id' => 'file_123', 'filename' => 'batch.jsonl' })
      )

      expect(protocol.find('file_123').filename).to eq('batch.jsonl')
    end

    it 'downloads file content' do
      allow(connection).to receive(:get) do |url, &block|
        request = Struct.new(:headers).new({})
        block&.call(request)
        expect(url).to eq('files/file_123/content')
        Struct.new(:body).new('contents')
      end

      expect(protocol.download('file_123')).to eq('contents')
    end

    it 'refuses to list files for providers without listing' do
      expect { protocol.list_uris('gs://bucket') }.to raise_error(
        RubyLLM::Error, "openai doesn't support file listing"
      )
    end

    it 'rewraps an attachment when a new filename is given' do
      attachment = RubyLLM::Attachment.new(fixture_path)

      expect(protocol.send(:file_attachment, attachment)).to equal(attachment)
      expect(protocol.send(:file_attachment, attachment, filename: 'renamed.txt').filename).to eq('renamed.txt')
    end

    it 'reads a timestamp in every shape providers send' do
      expect(protocol.send(:timestamp, nil)).to be_nil
      expect(protocol.send(:timestamp, 0)).to eq(Time.at(0))
      expect(protocol.send(:timestamp, '2025-01-01T00:00:00Z')).to eq(Time.utc(2025, 1, 1))
    end

    it 'sizes a file from disk or from its content' do
      expect(protocol.send(:file_size, RubyLLM::Attachment.new(fixture_path))).to eq(File.size(fixture_path))
      expect(protocol.send(:file_size, RubyLLM::Attachment.new(StringIO.new('12345'), filename: 'a.txt'))).to eq(5)
    end

    describe '#file_part_source' do
      it 'passes a path through as a string' do
        expect(protocol.send(:file_part_source, RubyLLM::Attachment.new(fixture_path))).to eq(fixture_path)
      end

      it 'rewinds an IO source' do
        io = StringIO.new('bytes')
        io.read

        expect(protocol.send(:file_part_source, RubyLLM::Attachment.new(io, filename: 'a.txt')).read).to eq('bytes')
      end

      it 'wraps loaded content in an IO' do
        attachment = RubyLLM::Attachment.new(
          RubyLLM::UploadedFile.new(id: 'file_1', filename: 'a.txt', provider: 'openai')
        )
        allow(attachment).to receive(:content).and_return('bytes')

        expect(protocol.send(:file_part_source, attachment).read).to eq('bytes')
      end
    end

    describe '#with_file_body' do
      it 'streams a path from disk' do
        body = protocol.send(:with_file_body, RubyLLM::Attachment.new(fixture_path), &:read)

        expect(body).to include('Ruby')
      end

      it 'rewinds an IO before yielding it' do
        io = StringIO.new('bytes')
        io.read

        expect(protocol.send(:with_file_body, RubyLLM::Attachment.new(io, filename: 'a.txt'), &:read)).to eq('bytes')
      end

      it 'wraps loaded content in an IO' do
        attachment = RubyLLM::Attachment.new(
          RubyLLM::UploadedFile.new(id: 'file_1', filename: 'a.txt', provider: 'openai')
        )
        allow(attachment).to receive_messages(content: 'bytes', io_like?: false)

        expect(protocol.send(:with_file_body, attachment, &:read)).to eq('bytes')
      end
    end
  end
end
