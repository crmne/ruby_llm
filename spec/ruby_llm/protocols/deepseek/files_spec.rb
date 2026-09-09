# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::DeepSeek::Files do
  let(:provider) do
    config = RubyLLM.config.dup
    config.deepseek_api_key ||= 'test'
    RubyLLM::Providers::DeepSeek.new(config)
  end
  let(:protocol) { described_class.new(provider) }
  let(:image_path) { File.expand_path('../../../fixtures/ruby.png', __dir__) }
  let(:image) { RubyLLM::Attachment.new(image_path) }

  it 'uses image uploads with user_data and anchored expiry' do
    payload = protocol.send(:render_upload_payload, image, expires_in: 3600)

    expect(payload).to include(purpose: 'user_data', expires_after: { anchor: 'created_at', seconds: 3600 })
    expect(payload[:file].original_filename).to eq('ruby.png')
    expect(provider).to be_files
  end

  it 'rejects non-image files' do
    text = RubyLLM::Attachment.new(StringIO.new('Ruby'), filename: 'ruby.txt')

    expect { protocol.send(:render_upload_payload, text) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
  end

  it 'rejects unsupported file purposes' do
    expect { protocol.send(:render_upload_payload, image, purpose: 'batch') }
      .to raise_error(ArgumentError, /user_data/)
  end

  it 'rejects images larger than the upload limit' do
    allow(protocol).to receive(:file_size).with(image).and_return((64 * 1024 * 1024) + 1)

    expect { protocol.send(:render_upload_payload, image) }.to raise_error(ArgumentError, /64 MiB/)
  end

  it 'reports that stored images cannot be downloaded' do
    file = protocol.send(:parse_file_response, { 'id' => 'file-api-image', 'filename' => 'ruby.png', 'bytes' => 10 })

    expect(file.downloadable).to be(false)
    expect { protocol.download(file.id) }.to raise_error(RubyLLM::Error, /does not support downloading/)
  end

  it 'uploads and retrieves an image with an expiry', :live do
    file = RubyLLM.upload(image_path, provider: :deepseek, expires_in: 3600)
    stored = RubyLLM::UploadedFile.find(file.id, provider: :deepseek)

    expect(stored).to have_attributes(id: file.id, filename: 'ruby.png', purpose: 'user_data')
    expect(stored.byte_size).to eq(File.size(image_path))
    expect(stored.expires_at).to be > stored.created_at
  ensure
    provider.connection.delete("files/#{file.id}") if file
  end
end
