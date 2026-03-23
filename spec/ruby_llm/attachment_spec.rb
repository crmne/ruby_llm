# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'rbconfig'
require 'stringio'
require 'tempfile'

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

  it 'saves io attachments without altering binary content' do
    binary_content = "\x00\xFFbinary\npayload".b
    io = StringIO.new(binary_content)
    io.read(2)
    attachment = described_class.new(io, filename: 'payload.bin')

    Tempfile.create('attachment') do |file|
      attachment.save(file.path)

      expect(File.binread(file.path)).to eq(binary_content)
    end
  end
end
