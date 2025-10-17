# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ActsAs do
  include_context 'with configured RubyLLM'

  let(:image_path) { File.expand_path('../../fixtures/ruby.png', __dir__) }
  let(:pdf_path) { File.expand_path('../../fixtures/sample.pdf', __dir__) }
  let(:model) { 'gpt-4.1-nano' }

  def uploaded_file(path, type)
    filename = File.basename(path)
    extension = File.extname(filename)
    name = File.basename(filename, extension)

    tempfile = Tempfile.new([name, extension])
    tempfile.binmode

    # Copy content from the real file to the Tempfile
    File.open(path, 'rb') do |real_file_io|
      tempfile.write(real_file_io.read)
    end

    tempfile.rewind # Prepare Tempfile for reading from the beginning

    ActionDispatch::Http::UploadedFile.new(
      tempfile: tempfile,
      filename: File.basename(tempfile.path),
      type: type
    )
  end

  describe 'attachment handling' do
    it 'converts ActiveStorage attachments to RubyLLM Content' do
      chat = Chat.create!(model: model)

      message = chat.messages.create!(role: 'user', content: 'Check this out')
      message.attachments.attach(
        io: File.open(image_path),
        filename: 'ruby.png',
        content_type: 'image/png'
      )

      llm_message = message.to_llm
      expect(llm_message.content).to be_a(RubyLLM::Content)
      expect(llm_message.content.attachments.first.mime_type).to eq('image/png')
    end

    it 'handles multiple attachments' do
      chat = Chat.create!(model: model)

      image_upload = uploaded_file(image_path, 'image/png')
      pdf_upload = uploaded_file(pdf_path, 'application/pdf')

      response = chat.ask('Analyze these', with: [image_upload, pdf_upload])

      user_message = chat.messages.find_by(role: 'user')
      expect(user_message.attachments.count).to eq(2)
      expect(response.content).to be_present
    end

    it 'handles attachments in ask method' do
      chat = Chat.create!(model: model)

      image_upload = uploaded_file(image_path, 'image/png')

      response = chat.ask('What do you see?', with: image_upload)

      user_message = chat.messages.find_by(role: 'user')
      expect(user_message.attachments.count).to eq(1)
      expect(response.content).to be_present
    end
  end

  describe 'attachment types' do
    it 'handles images' do
      chat = Chat.create!(model: model)
      message = chat.messages.create!(role: 'user', content: 'Image test')

      message.attachments.attach(
        io: File.open(image_path),
        filename: 'test.png',
        content_type: 'image/png'
      )

      llm_message = message.to_llm
      attachment = llm_message.content.attachments.first
      expect(attachment.type).to eq(:image)
    end

    it 'handles videos' do
      video_path = File.expand_path('../../fixtures/ruby.mp4', __dir__)
      chat = Chat.create!(model: model)
      message = chat.messages.create!(role: 'user', content: 'Video test')

      message.attachments.attach(
        io: File.open(video_path),
        filename: 'test.mp4',
        content_type: 'video/mp4'
      )

      llm_message = message.to_llm
      attachment = llm_message.content.attachments.first
      expect(attachment.type).to eq(:video)
    end

    it 'handles PDFs' do
      chat = Chat.create!(model: model)
      message = chat.messages.create!(role: 'user', content: 'PDF test')

      message.attachments.attach(
        io: File.open(pdf_path),
        filename: 'test.pdf',
        content_type: 'application/pdf'
      )

      llm_message = message.to_llm
      attachment = llm_message.content.attachments.first
      expect(attachment.type).to eq(:pdf)
    end
  end
end
