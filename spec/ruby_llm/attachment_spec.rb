# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'rbconfig'

RSpec.describe RubyLLM::Attachment do
  it 'supports path attachments from the public API' do
    script = <<~'RUBY'
      require 'ruby_llm'

      message = RubyLLM::Message.new(role: :user, content: 'What is in this file?',
                                     attachments: 'spec/fixtures/ruby.txt')
      attachment = message.attachments.first
      puts "#{attachment.filename},#{attachment.mime_type}"
    RUBY

    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, '-Ilib', '-e', script,
      chdir: File.expand_path('../..', __dir__)
    )

    expect(status.success?).to be(true), stderr
    expect(stdout.strip).to eq('ruby.txt,text/plain')
  end

  it 'normalizes text file content to UTF-8' do
    attachment = described_class.new(File.expand_path('../fixtures/ruby.txt', __dir__))

    expect(attachment.content.encoding).to eq(Encoding::UTF_8)
    expect(attachment.content).to be_valid_encoding
  end

  it 'keeps binary attachment content untouched' do
    attachment = described_class.new(File.expand_path('../fixtures/ruby.png', __dir__))

    expect(attachment.content.encoding).to eq(Encoding::ASCII_8BIT)
  end

  it 'classifies rich document files semantically' do
    attachment = described_class.new(StringIO.new('docx bytes'), filename: 'proposal.docx')

    expect(attachment.mime_type).to eq('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
    expect(attachment.type).to eq(:document)
    expect(attachment).to be_document
    expect(attachment.extension).to eq('docx')
  end

  it 'keeps text files in one attachment category' do
    attachment = described_class.new(StringIO.new('notes'), filename: 'notes.txt')

    expect(attachment.type).to eq(:text)
    expect(attachment).to be_text
    expect(attachment).not_to be_document
  end

  it 'wraps provider-managed files without reading inline content' do
    file = RubyLLM::UploadedFile.new(
      id: 'file_123',
      provider: 'anthropic',
      filename: 'proposal.pdf',
      byte_size: 1234,
      mime_type: 'application/pdf'
    )

    attachment = described_class.new(file)

    expect(attachment).to be_provider_file
    expect(attachment.provider_file_id).to eq('file_123')
    expect(attachment.filename).to eq('proposal.pdf')
    expect(attachment.mime_type).to eq('application/pdf')
    expect(attachment.byte_size).to eq(1234)
    expect { attachment.content }.to raise_error(RubyLLM::Error, /cannot be read as inline/)
  end

  it 'does not fetch URL content to determine byte size' do
    attachment = described_class.new('https://example.com/report.pdf')
    allow(RubyLLM::Connection).to receive(:basic).and_raise('unexpected network request')

    expect(attachment.byte_size).to be_nil
  end

  it 'treats partially loaded ActiveStorage constants as unavailable' do
    stub_const('ActiveStorage', Module.new)
    stub_const('ActiveStorage::Blob', Class.new)

    attachment = described_class.new(StringIO.new('notes'), filename: 'notes.txt')

    expect(attachment).not_to be_active_storage
    expect(attachment.content).to eq('notes')
  end

  describe 'provider-managed file accessors' do
    it 'reports no provider id or URI for ordinary sources' do
      attachment = described_class.new(StringIO.new('notes'), filename: 'notes.txt')

      expect(attachment.provider_file?).to be(false)
      expect(attachment.provider_file_id).to be_nil
      expect(attachment.provider_file_uri).to be_nil
    end

    it 'derives the mime type from the provider filename when the record has none' do
      file = RubyLLM::UploadedFile.new(id: 'file_1', filename: 'notes.txt', provider: 'openai')

      expect(described_class.new(file).mime_type).to eq('text/plain')
    end
  end

  describe '#extension' do
    it 'is nil for a filename without one' do
      expect(described_class.new(StringIO.new('x'), filename: 'README').extension).to be_nil
    end

    it 'downcases the extension' do
      expect(described_class.new(StringIO.new('x'), filename: 'REPORT.PDF').extension).to eq('pdf')
    end
  end

  describe '#byte_size' do
    it 'reads the size off an IO that reports one' do
      expect(described_class.new(StringIO.new('12345'), filename: 'a.txt').byte_size).to eq(5)
    end

    it 'falls back to the file stat' do
      File.open(File.expand_path('../fixtures/ruby.txt', __dir__), 'rb') do |io|
        io.singleton_class.undef_method(:size)

        expect(described_class.new(io, filename: 'ruby.txt').byte_size).to be_positive
      end
    end

    it 'uses the already-loaded content when the source cannot report a size' do
      source = StringIO.new('loaded bytes')
      source.singleton_class.undef_method(:size)
      attachment = described_class.new(source, filename: 'a.txt')
      attachment.content

      expect(attachment.byte_size).to eq(12)
    end
  end

  describe 'unreadable sources' do
    it 'warns and reports no content' do
      allow(RubyLLM.logger).to receive(:warn)
      attachment = described_class.new(Object.new, filename: 'mystery.bin')

      expect(attachment.content).to be_nil
      expect(attachment.byte_size).to be_nil
      expect(RubyLLM.logger).to have_received(:warn).with(
        /neither a URL, path, ActiveStorage, nor IO-like/
      ).at_least(:once)
    end
  end

  describe 'text encoding' do
    it 'scrubs invalid byte sequences in text content' do
      attachment = described_class.new(StringIO.new("bad \xC3(".b), filename: 'notes.txt')

      expect(attachment.content.encoding).to eq(Encoding::UTF_8)
      expect(attachment.content).to be_valid_encoding
    end

    it 'leaves binary content in its original encoding' do
      attachment = described_class.new(StringIO.new("\x89PNG".b), filename: 'image.png')

      expect(attachment.content.encoding).to eq(Encoding::ASCII_8BIT)
    end
  end

  describe '#filename' do
    it 'reads the original filename off an uploaded file' do
      tempfile = Tempfile.new(%w[upload .txt])
      tempfile.write('x')
      tempfile.rewind
      source = StringIO.new('x')
      source.define_singleton_method(:path) { tempfile.path }

      expect(described_class.new(source).filename).to eq(File.basename(tempfile.path))
    end

    it 'falls back to a generic name for an anonymous IO' do
      expect(described_class.new(StringIO.new('x')).filename).to eq('attachment')
    end

    it 'takes the basename of a URL path' do
      expect(described_class.new('https://example.com/docs/report.pdf').filename).to eq('report.pdf')
    end
  end

  describe 'document classification' do
    it 'is not a document when it is a PDF or plain text' do
      expect(described_class.new(StringIO.new('x'), filename: 'a.pdf')).not_to be_document
      expect(described_class.new(StringIO.new('x'), filename: 'a.txt')).not_to be_document
      expect(described_class.new(StringIO.new('x'), filename: 'a.docx')).to be_document
    end

    it 'reports unknown for a type it cannot place' do
      expect(described_class.new(StringIO.new('x'), filename: 'a.bin').type).to eq(:unknown)
    end
  end

  describe 'provider-managed files' do
    it 'takes the size and filename off the record' do
      file = RubyLLM::UploadedFile.new(
        id: 'file_1', provider: 'openai', filename: 'batch.jsonl', byte_size: 42, mime_type: 'application/jsonl'
      )
      attachment = described_class.new(file)

      expect(attachment.byte_size).to eq(42)
      expect(attachment.filename).to eq('batch.jsonl')
      expect(attachment.mime_type).to eq('application/jsonl')
      expect(attachment.provider_file_id).to eq('file_1')
    end
  end
end
