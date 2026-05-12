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
end
