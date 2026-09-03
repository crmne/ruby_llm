# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Bedrock::Files do
  let(:config) do
    RubyLLM::Configuration.new.tap do |c|
      c.bedrock_region = 'us-east-1'
      c.bedrock_api_key = 'key'
      c.bedrock_secret_key = 'secret'
      c.bedrock_session_token = 'token'
      c.bedrock_batch_s3_uri = 's3://ruby-llm-test/batches/'
    end
  end

  let(:provider) { RubyLLM::Providers::Bedrock.new(config) }
  let(:files) { described_class.new(provider) }
  # Stands in for Aws::S3::Client, which is an optional dependency here.
  let(:s3_class) do
    Class.new do
      def put_object(**); end
      def head_object(**); end
      def get_object(**); end
      def list_objects_v2(**); end
    end
  end
  let(:s3) { instance_double(s3_class) }

  before { allow(files).to receive(:s3_client).and_return(s3) }

  describe '#upload' do
    it 'puts the file under the configured prefix' do
      allow(s3).to receive(:put_object)

      file = files.upload(StringIO.new('{"a":1}'), filename: 'batch.jsonl')

      expect(file.uri).to match(%r{\As3://ruby-llm-test/batches/ruby_llm_uploads/[0-9a-f]{16}/batch\.jsonl\z})
      expect(file.id).to eq(file.uri)
      expect(file.filename).to eq('batch.jsonl')
      expect(file.byte_size).to eq(7)
      expect(file.mime_type).to eq('application/jsonl')
      expect(s3).to have_received(:put_object).with(
        bucket: 'ruby-llm-test', key: %r{\Abatches/ruby_llm_uploads/}, body: instance_of(StringIO),
        content_type: 'application/jsonl'
      )
    end

    it 'honours an explicit destination and content type' do
      allow(s3).to receive(:put_object)

      file = files.upload(
        StringIO.new('x'), filename: 'batch.jsonl',
                           provider_options: { uri: 's3://other/in.jsonl', content_type: 'text/plain' }
      )

      expect(file.uri).to eq('s3://other/in.jsonl')
      expect(file.mime_type).to eq('text/plain')
      expect(s3).to have_received(:put_object).with(
        bucket: 'other', key: 'in.jsonl', body: instance_of(StringIO), content_type: 'text/plain'
      )
    end

    it 'requires a configured bucket prefix' do
      config.bedrock_batch_s3_uri = nil

      expect { files.upload(StringIO.new('x'), filename: 'batch.jsonl') }.to raise_error(
        RubyLLM::ConfigurationError, /Set bedrock_batch_s3_uri/
      )
    end

    it 'rejects a destination that is not an s3 URI' do
      expect { files.upload(StringIO.new('x'), filename: 'batch.jsonl', provider_options: { uri: 'https://example.test/x' }) }
        .to raise_error(ArgumentError, %r{Expected an s3:// URI})
    end
  end

  describe '#find' do
    it 'reads the object metadata' do
      allow(s3).to receive(:head_object).and_return(
        Struct.new(:content_length, :last_modified, :content_type)
              .new(42, Time.at(0), 'application/jsonl')
      )

      file = files.find('s3://ruby-llm-test/batches/out.jsonl')

      expect(file.filename).to eq('out.jsonl')
      expect(file.byte_size).to eq(42)
      expect(file.created_at).to eq(Time.at(0))
      expect(file.mime_type).to eq('application/jsonl')
    end
  end

  describe '#download' do
    it 'reads the object body' do
      allow(s3).to receive(:get_object).and_return(Struct.new(:body).new(StringIO.new('contents')))

      expect(files.download('s3://ruby-llm-test/batches/out.jsonl')).to eq('contents')
    end
  end

  describe '#list_uris' do
    it 'pages through every object under the prefix' do
      page = Struct.new(:contents, :next_continuation_token)
      object = Struct.new(:key)
      allow(s3).to receive(:list_objects_v2).with(bucket: 'ruby-llm-test', prefix: 'batches/').and_return(
        page.new([object.new('batches/a.jsonl')], 'token-1')
      )
      allow(s3).to receive(:list_objects_v2).with(
        bucket: 'ruby-llm-test', prefix: 'batches/', continuation_token: 'token-1'
      ).and_return(page.new([object.new('batches/b.jsonl')], nil))

      expect(files.list_uris('s3://ruby-llm-test/batches/')).to eq(
        ['s3://ruby-llm-test/batches/a.jsonl', 's3://ruby-llm-test/batches/b.jsonl']
      )
    end
  end

  describe '#s3_client_options' do
    it 'passes static credentials through' do
      expect(files.send(:s3_client_options)).to eq(
        region: 'us-east-1', access_key_id: 'key', secret_access_key: 'secret', session_token: 'token'
      )
    end

    it 'prefers a credential provider' do
      credential_provider = Struct.new(:credentials).new(:creds)
      config.bedrock_credential_provider = credential_provider

      expect(files.send(:s3_client_options)).to eq(region: 'us-east-1', credentials: credential_provider)
    end
  end

  describe 'the aws-sdk-s3 dependency' do
    it 'explains how to install it when missing' do
      allow(files).to receive(:s3_client).and_call_original
      allow(files).to receive(:require).with('aws-sdk-s3').and_raise(LoadError)

      expect { files.send(:s3_client) }.to raise_error(RubyLLM::Error, /aws-sdk-s3 gem is required/)
    end
  end
end
