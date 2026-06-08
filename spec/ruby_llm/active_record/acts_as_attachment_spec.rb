# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

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

  def attachment_io(path)
    StringIO.new(File.binread(path))
  end

  def attachment_host
    attachment_host_class.create!
  end

  def attachment_host_class
    @attachment_host_class ||= stub_const('AttachmentHost', Class.new(ApplicationRecord) do
      self.table_name = 'chats'

      has_one_attached :file
      has_many_attached :files
    end)
  end

  describe 'attachment handling' do
    it 'converts ActiveStorage attachments to RubyLLM Content' do
      chat = Chat.create!(model: model)

      message = chat.messages.create!(role: 'user', content: 'Check this out')
      message.attachments.attach(
        io: attachment_io(image_path),
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

    it 'uses the original upload for ask with attachments inside a transaction' do
      chat = Chat.create!(model: model)
      captured_messages = nil

      allow_any_instance_of(RubyLLM::Providers::OpenAI).to receive(:complete) do |_provider, messages, **| # rubocop:disable RSpec/AnyInstance
        captured_messages = messages
        RubyLLM::Message.new(role: :assistant, content: 'I can see it')
      end
      allow_any_instance_of(ActiveStorage::Attachment).to receive(:download) # rubocop:disable RSpec/AnyInstance
        .and_raise(ActiveStorage::FileNotFoundError)

      image_upload = uploaded_file(image_path, 'image/png')

      response = nil
      Chat.transaction do
        response = chat.ask('What do you see?', with: image_upload)
      end

      user_message = chat.messages.find_by(role: 'user')
      llm_user_message = captured_messages.find { |message| message.role == :user }

      expect(user_message.attachments.count).to eq(1)
      expect(llm_user_message.content.attachments.first.filename).to eq(image_upload.original_filename)
      expect(llm_user_message.content.attachments.first.content).to eq(File.binread(image_path))
      expect(response.content).to eq('I can see it')
    end

    it 'ignores leading blank multipart attachment entries for create_user_message' do
      chat = Chat.create!(model: model)
      image_upload = uploaded_file(image_path, 'image/png')

      expect do
        chat.create_user_message('What do you see?', with: ['', image_upload])
      end.not_to raise_error

      user_message = chat.messages.find_by(role: 'user')
      expect(user_message.attachments.count).to eq(1)
    end

    it 'reuses an existing ActiveStorage::Blob without re-uploading' do
      chat = Chat.create!(model: model)

      existing_blob = ActiveStorage::Blob.create_and_upload!(
        io: attachment_io(image_path),
        filename: 'ruby.png',
        content_type: 'image/png'
      )

      expect do
        chat.create_user_message('What do you see?', with: existing_blob)
      end.not_to change(ActiveStorage::Blob, :count)

      user_message = chat.messages.find_by(role: 'user')
      expect(user_message.attachments.count).to eq(1)
      expect(user_message.attachments.first.blob_id).to eq(existing_blob.id)
    end

    it 'reuses an ActiveStorage::Attached::One without re-uploading' do
      chat = Chat.create!(model: model)
      host = attachment_host
      host.file.attach(
        io: attachment_io(image_path),
        filename: 'ruby.png',
        content_type: 'image/png'
      )

      expect do
        chat.create_user_message('What do you see?', with: host.file)
      end.not_to change(ActiveStorage::Blob, :count)

      user_message = chat.messages.find_by(role: 'user')
      expect(user_message.attachments.count).to eq(1)
      expect(user_message.attachments.first.blob_id).to eq(host.file.blob.id)
    end

    it 'reuses ActiveStorage::Attached::Many without re-uploading' do
      chat = Chat.create!(model: model)
      host = attachment_host
      host.files.attach([
                          { io: attachment_io(image_path), filename: 'ruby.png', content_type: 'image/png' },
                          { io: attachment_io(pdf_path), filename: 'sample.pdf', content_type: 'application/pdf' }
                        ])
      blob_ids = host.files.blobs.map(&:id)

      expect do
        chat.create_user_message('Analyze these', with: host.files)
      end.not_to change(ActiveStorage::Blob, :count)

      user_message = chat.messages.find_by(role: 'user')
      expect(user_message.attachments.count).to eq(2)
      expect(user_message.attachments.map(&:blob_id)).to match_array(blob_ids)
      expect(user_message.attachments.map { |attachment| attachment.filename.to_s })
        .to match_array(%w[ruby.png sample.pdf])
    end
  end

  describe 'attachment types' do
    it 'handles images' do
      chat = Chat.create!(model: model)
      message = chat.messages.create!(role: 'user', content: 'Image test')

      message.attachments.attach(
        io: attachment_io(image_path),
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
        io: attachment_io(video_path),
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
        io: attachment_io(pdf_path),
        filename: 'test.pdf',
        content_type: 'application/pdf'
      )

      llm_message = message.to_llm
      attachment = llm_message.content.attachments.first
      expect(attachment.type).to eq(:pdf)
    end
  end
end
