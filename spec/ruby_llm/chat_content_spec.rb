# frozen_string_literal: true

require 'spec_helper'
require 'action_dispatch/http/upload'
RSpec.describe RubyLLM::Chat do # rubocop:disable RSpec/MultipleMemoizedHelpers
  include_context 'with configured RubyLLM'

  let(:image_path) { File.expand_path('../fixtures/ruby.png', __dir__) }
  let(:video_path) { File.expand_path('../fixtures/ruby.mp4', __dir__) }
  let(:audio_path) { File.expand_path('../fixtures/ruby.wav', __dir__) }
  let(:mp3_path) { File.expand_path('../fixtures/ruby.mp3', __dir__) }
  let(:pdf_path) { File.expand_path('../fixtures/sample.pdf', __dir__) }
  let(:text_path) { File.expand_path('../fixtures/ruby.txt', __dir__) }
  let(:xml_path) { File.expand_path('../fixtures/ruby.xml', __dir__) }
  let(:image_url) { 'https://upload.wikimedia.org/wikipedia/commons/f/f1/Ruby_logo.png' }
  let(:video_url) { 'https://filesamples.com/samples/video/mp4/sample_640x360.mp4' }
  let(:audio_url) { 'https://commons.wikimedia.org/wiki/File:LL-Q1860_(eng)-AcpoKrane-ruby.wav' }
  let(:pdf_url) { 'https://pdfobject.com/pdf/sample.pdf' }
  let(:text_url) { 'https://www.ruby-lang.org/en/about/license.txt' }
  let(:bad_image_url) { 'https://example.com/eiffel_tower' }
  let(:bad_image_path) { File.expand_path('../fixtures/bad_image.png', __dir__) }
  let(:image_url_no_ext) { 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQzSCawxoHrVtf9AX-o7bp7KVxcmkYWzsIjng&s' }

  describe 'text models' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    CHAT_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can understand text" do
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask("What's in this file?", with: text_path)

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first.filename).to eq('ruby.txt')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('text/plain')

        response = chat.ask('and in this one?', with: xml_path)

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages[2].content).to be_a(RubyLLM::Content)
        expect(chat.messages[2].content.attachments.first.filename).to eq('ruby.xml')
        expect(chat.messages[2].content.attachments.first.mime_type).to eq('application/xml')
      end

      it "#{provider}/#{model} can understand remote text" do
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask("What's in this file?", with: text_url)

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first.filename).to eq('license.txt')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('text/plain')
      end
    end
  end

  describe 'vision models' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    VISION_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can understand local images" do
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('What do you see in this image?', with: { image: image_path })

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first.filename).to eq('ruby.png')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('image/png')
      end

      it "#{provider}/#{model} can understand remote images without extension" do
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('What do you see in this image?', with: image_url_no_ext)

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first.filename).to eq('images')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('image/jpeg')
      end
    end
    model = VISION_MODELS.first[:model]
    provider = VISION_MODELS.first[:provider]
    it "return errors when content doesn't exist" do
      chat = RubyLLM.chat(model: model, provider: provider)
      expect do
        chat.ask('What do you see in this image?', with: bad_image_url)
      end.to raise_error(Faraday::ResourceNotFound)

      chat = RubyLLM.chat(model: model, provider: provider)
      expect do
        chat.ask('What do you see in this image?', with: bad_image_path)
      end.to raise_error(Errno::ENOENT)
    end
  end

  describe 'video models' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    VIDEO_MODELS.each do |model_info|
      provider = model_info[:provider]
      model = model_info[:model]

      it "#{provider}/#{model} can understand local videos" do
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('What do you see in this video?', with: { video: video_path })

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first.filename).to eq('ruby.mp4')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('video/mp4')
      end

      it "#{provider}/#{model} can understand remote videos without extension" do
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('What do you see in this video?', with: video_url)

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first.filename).to eq('sample_640x360.mp4')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('video/mp4')
      end
    end
  end

  describe 'audio models' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    AUDIO_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can understand audio" do
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('What is being said?', with: { audio: audio_path })

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first.filename).to eq('ruby.wav')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('audio/wav')
      end

      it "#{provider}/#{model} can understand MP3 audio" do
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('What is being said?', with: { audio: mp3_path })

        expect(response.content).to be_present
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first.filename).to eq('ruby.mp3')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('audio/mpeg')
        expect(chat.messages.first.content.attachments.first.format).to eq('mp3')
      end
    end
  end

  describe 'pdf models' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    PDF_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} understands PDFs" do
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('Summarize this document', with: { pdf: pdf_path })
        expect(response.content).not_to be_empty
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content.attachments.first.filename).to eq('sample.pdf')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('application/pdf')

        response = chat.ask 'go on'
        expect(response.content).not_to be_empty
      end

      it "#{provider}/#{model} handles multiple PDFs" do
        chat = RubyLLM.chat(model: model, provider: provider)
        # Using same file twice for testing
        response = chat.ask('Compare these documents', with: [pdf_path, pdf_url])
        expect(response.content).not_to be_empty
        expect(response.content).not_to include('RubyLLM::Content')
        expect(chat.messages.first.content.attachments.first.filename).to eq('sample.pdf')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('application/pdf')
        expect(chat.messages.first.content.attachments.second.filename).to eq('sample.pdf')
        expect(chat.messages.first.content.attachments.second.mime_type).to eq('application/pdf')

        response = chat.ask 'go on'
        expect(response.content).not_to be_empty
      end

      it "#{provider}/#{model} can handle array of mixed files with auto-detection" do
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('Analyze these files', with: [image_path, pdf_path])

        expect(response.content).to be_present
        expect(chat.messages.first.content).to be_a(RubyLLM::Content)
        expect(chat.messages.first.content.attachments.first.filename).to eq('ruby.png')
        expect(chat.messages.first.content.attachments.first.mime_type).to eq('image/png')
        expect(chat.messages.first.content.attachments.second.filename).to eq('sample.pdf')
        expect(chat.messages.first.content.attachments.second.mime_type).to eq('application/pdf')
      end
    end
  end

  describe 'URL attachment handling' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    it 'handles URL MIME type detection without ArgumentError' do
      attachment = RubyLLM::Attachment.new(image_url)

      expect(attachment.mime_type).to be_present
    end

    it 'creates content with URL attachments' do
      content = RubyLLM::Content.new('Describe this image', image_url)

      expect(content.attachments).not_to be_empty
      expect(content.attachments.first).to be_a(RubyLLM::Attachment)
    end

    it 'prevents ArgumentError: wrong number of arguments when processing URL attachments' do
      require 'open-uri' # required to trigger the marcel/open-uri compatibility issue

      attachment = RubyLLM::Attachment.new(image_url)

      expect { attachment.mime_type }.not_to raise_error

      expect(attachment.mime_type).to eq('image/png')
      expect(attachment.send(:url?)).to be true
    end
  end

  describe 'IO attachment handling' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    it 'handles StringIO objects' do
      require 'stringio'
      text_content = 'Hello, this is a test file'
      string_io = StringIO.new(text_content)

      attachment = RubyLLM::Attachment.new(string_io)

      expect(attachment.io_like?).to be true
      expect(attachment.content).to eq(text_content)
      expect(attachment.filename).to eq('attachment')
      expect(attachment.mime_type).to eq('application/octet-stream')
    end

    it 'handles StringIO objects with filename' do
      require 'stringio'
      text_content = 'Hello, this is a test file'
      string_io = StringIO.new(text_content)

      attachment = RubyLLM::Attachment.new(string_io, filename: 'test.txt')

      expect(attachment.io_like?).to be true
      expect(attachment.content).to eq(text_content)
      expect(attachment.filename).to eq('test.txt')
      expect(attachment.mime_type).to eq('text/plain')
    end

    it 'handles Tempfile objects' do
      tempfile = Tempfile.new(['test', '.txt'])
      tempfile.write('Tempfile content')
      tempfile.rewind

      attachment = RubyLLM::Attachment.new(tempfile)

      expect(attachment.io_like?).to be true
      expect(attachment.content).to eq('Tempfile content')
      expect(attachment.filename).to be_present
      expect(attachment.mime_type).to eq('text/plain')
    end

    it 'handles File objects' do
      file = File.open(text_path, 'r')

      attachment = RubyLLM::Attachment.new(file)

      expect(attachment.io_like?).to be true
      expect(attachment.content).to be_present
      expect(attachment.filename).to eq('ruby.txt')
      expect(attachment.mime_type).to eq('text/plain')

      file.close
    end

    it 'handles ActionDispatch::Http::UploadedFile' do
      tempfile = Tempfile.new(['ruby', '.png'])
      tempfile.binmode
      File.open(image_path, 'rb') { |f| tempfile.write(f.read) }
      tempfile.rewind

      uploaded_file = ActionDispatch::Http::UploadedFile.new(
        tempfile: tempfile,
        filename: 'ruby.png',
        type: 'image/png'
      )

      attachment = RubyLLM::Attachment.new(uploaded_file)

      expect(attachment.io_like?).to be true
      expect(attachment.content).to be_present
      expect(attachment.filename).to eq('ruby.png')
      expect(attachment.mime_type).to eq('image/png')
      expect(attachment.type).to eq(:image)
    end

    it 'rewinds IO objects before reading' do
      require 'stringio'
      string_io = StringIO.new('Initial content')
      string_io.read # Move position to end

      attachment = RubyLLM::Attachment.new(string_io, filename: 'test.txt')

      expect(attachment.content).to eq('Initial content')
    end

    it 'creates content with IO attachments' do
      require 'stringio'
      string_io = StringIO.new('Test content')
      content = RubyLLM::Content.new('Check this')
      content.add_attachment(string_io, filename: 'test.txt')

      expect(content.attachments).not_to be_empty
      expect(content.attachments.first).to be_a(RubyLLM::Attachment)
      expect(content.attachments.first.io_like?).to be true
      expect(content.attachments.first.filename).to eq('test.txt')
      expect(content.attachments.first.mime_type).to eq('text/plain')
    end
  end
end
