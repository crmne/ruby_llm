# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RubyLLM::DownloadedFile do
  let(:context) do
    RubyLLM.context do |config|
      config.openai_api_key = 'download-test-key'
      config.openai_api_base = 'https://files.example/v1'
      config.default_model = model_for(:openai)
    end
  end
  let(:body) { "\x00\xFF\r\n".b }

  before do
    stub_request(:get, 'https://files.example/v1/files/file_123/content')
      .with(headers: { 'Authorization' => 'Bearer download-test-key' })
      .to_return(body:, headers: { 'Content-Type' => 'application/octet-stream' })
  end

  it 'downloads and saves binary bytes through the public API' do
    file = RubyLLM.download('file_123', provider: :openai, context:)

    expect(file).to be_a(described_class)
    expect(file.to_blob).to eq(body)
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'report.bin')
      expect(file.save(path)).to eq(path)
      expect(File.binread(path)).to eq(body)
    end
  end

  it 'uses the context default provider and keeps existing string operations' do
    file = context.download('file_123')

    expect(file).to be_a(String)
    expect(file).to eq(body)
    expect(file.bytes).to eq(body.bytes)
    expect(file.lines).to eq(body.lines)
    expect(file.to_blob.encoding).to eq(body.encoding)
  end

  it 'keeps downloaded content out of inspect' do
    file = context.download('file_123')

    expect(file.inspect).to include('RubyLLM::DownloadedFile', 'byte_size: 4')
    expect(file.inspect).not_to include('\\xFF')
  end
end
