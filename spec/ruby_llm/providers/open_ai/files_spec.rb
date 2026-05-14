# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Files do
  let(:helper_host) do
    Class.new do
      include RubyLLM::Providers::OpenAI::Files
    end.new
  end

  describe '.files_url' do
    it 'returns the files endpoint path' do
      expect(helper_host.files_url).to eq('files')
    end
  end

  describe '.file_info_url' do
    it 'returns the file info endpoint path' do
      expect(helper_host.file_info_url('file_123')).to eq('files/file_123')
    end
  end

  describe '.download_file_url' do
    it 'returns the file content endpoint path' do
      expect(helper_host.download_file_url('file_123')).to eq('files/file_123/content')
    end
  end

  describe '.render_file_payload' do
    it 'renders file payload with purpose and expires_after' do
      upload_io = instance_double(Faraday::UploadIO)
      expires_after = { anchor: 'created_at', seconds: 3600 }

      allow(helper_host).to receive(:build_file).with('spec/fixtures/openai_batch.jsonl').and_return(upload_io)

      payload = helper_host.render_file_payload('spec/fixtures/openai_batch.jsonl',
                                                purpose: 'batch',
                                                expires_after: expires_after)

      expect(payload).to eq(
        file: upload_io,
        purpose: 'batch',
        expires_after: expires_after
      )
    end

    it 'omits expires_after when nil' do
      upload_io = instance_double(Faraday::UploadIO)

      allow(helper_host).to receive(:build_file).with('spec/fixtures/openai_batch.jsonl').and_return(upload_io)

      payload = helper_host.render_file_payload('spec/fixtures/openai_batch.jsonl', purpose: 'batch')

      expect(payload).to eq(
        file: upload_io,
        purpose: 'batch'
      )
    end
  end

  describe '.parse_file_response' do
    it 'parses OpenAI file metadata into a ProviderFile' do
      response = instance_double(
        Faraday::Response,
        body: {
          'id' => 'file_123',
          'filename' => 'openai_batch.jsonl',
          'bytes' => 123,
          'created_at' => 1_700_000_000
        }
      )

      file = helper_host.parse_file_response(response)

      expect(file).to be_a(RubyLLM::ProviderFile)
      expect(file.id).to eq('file_123')
      expect(file.filename).to eq('openai_batch.jsonl')
      expect(file.byte_size).to eq(123)
      expect(file.created_at).to eq(Time.at(1_700_000_000))
    end
  end

  describe '.build_file' do
    let(:text_fixture_path) { File.expand_path('../../../fixtures/ruby.txt', __dir__) }
    let(:batch_fixture_path) { File.expand_path('../../../fixtures/openai_batch.jsonl', __dir__) }

    it 'builds an upload from a file path' do
      upload = described_class.build_file(batch_fixture_path)

      expect(upload).to be_a(Faraday::UploadIO)
      expect(upload.content_type).to eq('application/octet-stream')
      expect(upload.original_filename).to eq('openai_batch.jsonl')
      expect(upload.local_path).to eq(batch_fixture_path)
    end

    it 'builds an upload from an io-like object' do
      io = StringIO.new("{\"hello\":\"world\"}\n")
      attachment = RubyLLM::Attachment.new(io, filename: 'inline.jsonl')

      upload = described_class.build_file(attachment)

      expect(upload).to be_a(Faraday::UploadIO)
      expect(upload.content_type).to eq('application/octet-stream')
      expect(upload.original_filename).to eq('inline.jsonl')
    end

    it 'rewinds io-like input before upload when possible' do
      io = StringIO.new("{\"hello\":\"world\"}\n")
      io.read
      attachment = RubyLLM::Attachment.new(io, filename: 'inline.jsonl')

      described_class.build_file(attachment)

      expect(io.pos).to eq(0)
    end

    it 'reuses an attachment input' do
      attachment = RubyLLM::Attachment.new(text_fixture_path)

      allow(RubyLLM::Attachment).to receive(:new).and_call_original

      upload = described_class.build_file(attachment)

      expect(RubyLLM::Attachment).not_to have_received(:new)
      expect(upload).to be_a(Faraday::UploadIO)
      expect(upload.original_filename).to eq('ruby.txt')
    end
  end
end
