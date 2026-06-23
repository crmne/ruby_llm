# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'rbconfig'

RSpec.describe RubyLLM::Attachment do
  it 'supports path attachments from the public API' do
    script = <<~'RUBY'
      require 'ruby_llm'

      content = RubyLLM::Content.new('What is in this file?', 'spec/fixtures/ruby.txt')
      attachment = content.attachments.first
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
end
