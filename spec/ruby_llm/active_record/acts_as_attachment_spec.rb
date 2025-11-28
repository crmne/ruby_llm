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

  describe 'include_attachments parameter' do
    describe 'basic functionality' do
      it 'excludes attachments when include_attachments: false' do
        chat = Chat.create!(model: model)
        message = chat.messages.create!(role: 'user', content: 'Test message')
        message.attachments.attach(
          io: File.open(image_path),
          filename: 'ruby.png',
          content_type: 'image/png'
        )

        llm_message = message.to_llm(include_attachments: false)

        expect(llm_message.content).to be_a(String)
        expect(llm_message.content).to eq('Test message')
        expect(llm_message.content).not_to be_a(RubyLLM::Content)
      end

      it 'includes attachments by default' do
        chat = Chat.create!(model: model)
        message = chat.messages.create!(role: 'user', content: 'Test message')
        message.attachments.attach(
          io: File.open(image_path),
          filename: 'ruby.png',
          content_type: 'image/png'
        )

        llm_message = message.to_llm

        expect(llm_message.content).to be_a(RubyLLM::Content)
        expect(llm_message.content.attachments).not_to be_empty
      end

      it 'includes attachments when include_attachments: true' do
        chat = Chat.create!(model: model)
        message = chat.messages.create!(role: 'user', content: 'Test message')
        message.attachments.attach(
          io: File.open(image_path),
          filename: 'ruby.png',
          content_type: 'image/png'
        )

        llm_message = message.to_llm(include_attachments: true)

        expect(llm_message.content).to be_a(RubyLLM::Content)
        expect(llm_message.content.attachments).not_to be_empty
      end
    end

    describe 'with multiple attachments' do
      it 'excludes all attachments when false' do
        chat = Chat.create!(model: model)
        message = chat.messages.create!(role: 'user', content: 'Multiple files')

        message.attachments.attach(
          io: File.open(image_path),
          filename: 'ruby.png',
          content_type: 'image/png'
        )
        message.attachments.attach(
          io: File.open(pdf_path),
          filename: 'sample.pdf',
          content_type: 'application/pdf'
        )

        llm_message = message.to_llm(include_attachments: false)

        expect(llm_message.content).to eq('Multiple files')
        expect(llm_message.content).not_to be_a(RubyLLM::Content)
      end
    end

    describe 'with messages without attachments' do
      it 'works normally when include_attachments: false and no attachments' do
        chat = Chat.create!(model: model)
        message = chat.messages.create!(role: 'user', content: 'Plain text')

        llm_message = message.to_llm(include_attachments: false)

        expect(llm_message.content).to eq('Plain text')
      end

      it 'works normally when include_attachments: true and no attachments' do
        chat = Chat.create!(model: model)
        message = chat.messages.create!(role: 'user', content: 'Plain text')

        llm_message = message.to_llm(include_attachments: true)

        expect(llm_message.content).to eq('Plain text')
      end
    end

    describe 'performance use case' do
      it 'enables skipping attachment downloads for old messages' do
        chat = Chat.create!(model: model)

        # Create messages with attachments (stagger timestamps to ensure order)
        message_ids = []
        5.times do |i|
          msg = chat.messages.create!(role: 'user', content: "Message #{i}")
          msg.attachments.attach(
            io: File.open(image_path),
            filename: "image_#{i}.png",
            content_type: 'image/png'
          )
          message_ids << msg.id
          sleep 0.01 if i < 4 # Small delay to ensure distinct timestamps
        end

        # For performance testing: only download attachments for recent messages
        # Treat last 2 messages as "recent" (by ID)
        all_ids = chat.messages.order(id: :asc).pluck(:id)
        recent_ids = all_ids.last(2) # Get the last 2 IDs

        llm_messages = chat.messages.order(id: :asc).map do |msg|
          include_attachments = recent_ids.include?(msg.id)
          msg.to_llm(include_attachments: include_attachments)
        end

        # Old messages (first 3) should NOT have attachments (just strings)
        old_messages = llm_messages.first(3)
        expect(old_messages.all? { |m| m.content.is_a?(String) }).to be true

        # Recent messages (last 2) should have attachments (Content objects)
        recent_messages = llm_messages.last(2)
        expect(recent_messages.all? { |m| m.content.is_a?(RubyLLM::Content) }).to be true
      end
    end

    describe 'with content_raw' do
      it 'respects content_raw even when include_attachments: false' do
        skip 'content_raw requires v1.9 migration' unless Chat.new.respond_to?(:content_raw=)

        chat = Chat.create!(model: model)
        message = chat.messages.create!(
          role: 'user',
          content: 'Text',
          content_raw: { type: 'complex', data: 'raw' }
        )
        message.attachments.attach(
          io: File.open(image_path),
          filename: 'ruby.png'
        )

        llm_message = message.to_llm(include_attachments: false)

        # content_raw takes precedence
        expect(llm_message.content).to be_a(RubyLLM::Content::Raw)
      end
    end

    describe 'custom overrides' do
      around do |example|
        Message.class_eval do
          attr_accessor :include_attachment_override
          alias_method :__original_to_llm, :to_llm

          def to_llm(include_attachments: true)
            include_attachments &&= include_attachment_override != false
            __original_to_llm(include_attachments:)
          end
        end

        example.run
      ensure
        Message.class_eval do
          alias_method :to_llm, :__original_to_llm
          remove_method :__original_to_llm
          remove_method :include_attachment_override
          remove_method :include_attachment_override=
        end
      end

      it 'allows message-level include_attachments customizations' do
        chat = Chat.create!(model: model)
        message = chat.messages.create!(role: 'user', content: 'Configurable')
        message.attachments.attach(
          io: File.open(image_path),
          filename: 'ruby.png',
          content_type: 'image/png'
        )

        message.include_attachment_override = false

        llm_message = message.to_llm
        expect(llm_message.content).to eq('Configurable')
        expect(llm_message.content).not_to be_a(RubyLLM::Content)
      end
    end
  end
end
