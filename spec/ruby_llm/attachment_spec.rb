# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Attachment do
  let(:image_path) { File.expand_path('../fixtures/ruby.png', __dir__) }
  let(:text_path) { File.expand_path('../fixtures/ruby.txt', __dir__) }
  let(:image_url) { 'https://example.com/image.png' }

  describe 'initialization with file path' do
    it 'creates an attachment from a file path string' do
      attachment = described_class.new(image_path)

      expect(attachment.source).to be_a(Pathname)
      expect(attachment.path?).to be true
      expect(attachment.url?).to be false
      expect(attachment.filename).to eq('ruby.png')
    end

    it 'handles text file paths' do
      attachment = described_class.new(text_path)

      expect(attachment.source).to be_a(Pathname)
      expect(attachment.path?).to be true
      expect(attachment.mime_type).to eq('text/plain')
    end

    it 'distinguishes between paths and URLs' do
      path_attachment = described_class.new(image_path)
      url_attachment = described_class.new(image_url)

      expect(path_attachment.path?).to be true
      expect(path_attachment.url?).to be false

      expect(url_attachment.url?).to be true
      expect(url_attachment.path?).to be false
    end
  end

  describe 'initialization with Pathname' do
    it 'accepts a Pathname object directly' do
      pathname = Pathname.new(image_path)
      attachment = described_class.new(pathname)

      expect(attachment.source).to be_a(Pathname)
      expect(attachment.path?).to be true
      expect(attachment.filename).to eq('ruby.png')
    end
  end

  describe 'initialization with URL' do
    it 'creates an attachment from a URL string' do
      attachment = described_class.new(image_url)

      expect(attachment.source).to be_a(URI::HTTPS)
      expect(attachment.url?).to be true
      expect(attachment.path?).to be false
      expect(attachment.filename).to eq('image.png')
    end
  end
end
