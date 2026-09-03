# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::VertexAI::Files do
  let(:config) do
    RubyLLM::Configuration.new.tap do |c|
      c.vertexai_project_id = 'test-project'
      c.vertexai_location = 'global'
      c.vertexai_batch_gcs_uri = 'gs://ruby-llm-test/batches/'
    end
  end

  let(:provider) { RubyLLM::Providers::VertexAI.new(config) }
  let(:files) { described_class.new(provider) }

  # Stand in for Google::Cloud::Storage, an optional dependency here.
  let(:bucket) do
    instance_double(
      Class.new do
        def create_file(*, **); end
        def file(_key); end
        def files(**); end
      end
    )
  end
  let(:storage) { instance_double(Class.new { def bucket(_name); end }) }

  before do
    allow(files).to receive(:storage).and_return(storage)
    allow(storage).to receive(:bucket).and_return(bucket)
  end

  describe '#upload' do
    it 'writes the file under the configured prefix' do
      allow(bucket).to receive(:create_file)

      file = files.upload(StringIO.new('{"a":1}'), filename: 'batch.jsonl')

      expect(file.uri).to match(%r{\Ags://ruby-llm-test/batches/ruby_llm_uploads/[0-9a-f]{16}/batch\.jsonl\z})
      expect(file.byte_size).to eq(7)
      expect(file.mime_type).to eq('application/jsonl')
      expect(bucket).to have_received(:create_file).with(
        instance_of(StringIO), %r{\Abatches/ruby_llm_uploads/}, content_type: 'application/jsonl'
      )
    end

    it 'honours an explicit destination and content type' do
      allow(bucket).to receive(:create_file)

      file = files.upload(
        StringIO.new('x'), filename: 'batch.jsonl',
                           provider_options: { uri: 'gs://other/in.jsonl', content_type: 'text/plain' }
      )

      expect(file.uri).to eq('gs://other/in.jsonl')
      expect(bucket).to have_received(:create_file).with(
        instance_of(StringIO), 'in.jsonl', content_type: 'text/plain'
      )
    end

    it 'keeps spaces and non-ASCII in the object name' do
      allow(bucket).to receive(:create_file)

      file = files.upload(StringIO.new('x'), filename: 'Q3 übersicht.pdf')

      expect(file.uri).to end_with('/Q3 übersicht.pdf')
      expect(bucket).to have_received(:create_file).with(
        instance_of(StringIO), %r{/Q3 übersicht\.pdf\z}, content_type: 'application/pdf'
      )
    end

    it 'requires a configured bucket prefix' do
      config.vertexai_batch_gcs_uri = nil

      expect { files.upload(StringIO.new('x'), filename: 'batch.jsonl') }.to raise_error(
        RubyLLM::ConfigurationError, /Set vertexai_batch_gcs_uri/
      )
    end

    it 'rejects a destination that is not a gs URI' do
      expect do
        files.upload(StringIO.new('x'), filename: 'batch.jsonl', provider_options: { uri: 's3://bucket/in.jsonl' })
      end
        .to raise_error(ArgumentError, %r{Expected a gs:// URI})
    end
  end

  describe '#find' do
    it 'reads the object metadata' do
      object = Object.new
      object.define_singleton_method(:size) { 42 }
      object.define_singleton_method(:created_at) { Time.at(0) }
      object.define_singleton_method(:content_type) { 'application/jsonl' }
      allow(bucket).to receive(:file).and_return(object)

      file = files.find('gs://ruby-llm-test/batches/out.jsonl')

      expect(file.filename).to eq('out.jsonl')
      expect(file.byte_size).to eq(42)
      expect(file.created_at).to eq(Time.at(0))
    end

    it 'raises when the object is missing' do
      allow(bucket).to receive(:file).and_return(nil)

      expect { files.find('gs://ruby-llm-test/batches/out.jsonl') }.to raise_error(
        RubyLLM::Error, /GCS object not found/
      )
    end
  end

  describe '#download' do
    it 'reads the object body' do
      allow(bucket).to receive(:file).and_return(
        Struct.new(:download).new(StringIO.new('contents'))
      )

      expect(files.download('gs://ruby-llm-test/batches/out.jsonl')).to eq('contents')
    end

    it 'raises when the object is missing' do
      allow(bucket).to receive(:file).and_return(nil)

      expect { files.download('gs://ruby-llm-test/batches/out.jsonl') }.to raise_error(
        RubyLLM::Error, /GCS object not found/
      )
    end
  end

  describe '#list_uris' do
    it 'lists every object under the prefix' do
      listing = Object.new
      listing.define_singleton_method(:all) do |&block|
        [Struct.new(:name).new('batches/a.jsonl'), Struct.new(:name).new('batches/b.jsonl')].each(&block)
      end
      allow(bucket).to receive(:files).with(prefix: 'batches/').and_return(listing)

      expect(files.list_uris('gs://ruby-llm-test/batches/')).to eq(
        ['gs://ruby-llm-test/batches/a.jsonl', 'gs://ruby-llm-test/batches/b.jsonl']
      )
    end
  end

  describe 'bucket resolution' do
    it 'raises when the bucket does not exist' do
      allow(storage).to receive(:bucket).and_return(nil)

      expect { files.find('gs://missing/out.jsonl') }.to raise_error(RubyLLM::Error, /GCS bucket not found: missing/)
    end
  end

  describe 'the google-cloud-storage dependency' do
    it 'explains how to install it when missing' do
      allow(files).to receive(:storage).and_call_original
      allow(files).to receive(:require).with('google/cloud/storage').and_raise(LoadError)

      expect { files.send(:storage) }.to raise_error(RubyLLM::Error, /google-cloud-storage gem is required/)
    end
  end
end
