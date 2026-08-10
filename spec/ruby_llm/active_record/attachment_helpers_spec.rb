# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

RSpec.describe RubyLLM::ActiveRecord::AttachmentHelpers do
  subject(:helpers) do
    Class.new do
      include RubyLLM::ActiveRecord::AttachmentHelpers

      public :prepare_for_active_storage, :convert_to_active_storage_format, :active_storage_blobs,
             :plain_text_content, :action_text_attachment_sources, :action_text_attachable_sources,
             :content_attachments?, :pending_upload_attachable?, :pending_upload_attachment,
             :attachment_hash_io, :attachment_hash_filename, :instance_of_class?, :download_attachment,
             :persist_content
    end.new
  end

  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new('hello'), filename: 'hello.txt',
                                           content_type: 'text/plain')
  end

  def message_with_attachment
    chat = Chat.create!(model: 'gpt-4.1-nano')
    message = chat.messages.create!(role: 'user', content: 'see attached')
    message.attachments.attach(blob)
    message
  end

  def uploaded_file
    tempfile = Tempfile.new(%w[upload .txt])
    tempfile.write('uploaded')
    tempfile.rewind
    ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, filename: 'upload.txt', type: 'text/plain')
  end

  describe '#persist_content' do
    it 'does nothing for a record without an attachments association' do
      expect { helpers.persist_content(Object.new, [blob]) }.not_to raise_error
    end
  end

  describe '#prepare_for_active_storage' do
    it 'passes an uploaded file straight through' do
      file = uploaded_file

      expect(helpers.prepare_for_active_storage(file)).to eq([file])
    end

    it 'passes a blob straight through' do
      expect(helpers.prepare_for_active_storage(blob)).to eq([blob])
    end

    it 'resolves an attachment to its blob' do
      message = message_with_attachment

      expect(helpers.prepare_for_active_storage(message.attachments.first)).to eq([blob])
      expect(helpers.prepare_for_active_storage(message.attachments)).to eq([blob])
    end

    it 'walks a hash of attachables' do
      expect(helpers.prepare_for_active_storage({ file: blob })).to eq([blob])
    end

    it 'converts anything else into an upload hash' do
      prepared = helpers.prepare_for_active_storage(RubyLLM::Attachment.new(StringIO.new('x'), filename: 'x.txt'))

      expect(prepared.first).to include(filename: 'x.txt', content_type: 'text/plain')
    end
  end

  describe '#convert_to_active_storage_format' do
    it 'ignores a blank source' do
      expect(helpers.convert_to_active_storage_format(nil)).to be_nil
      expect(helpers.convert_to_active_storage_format('')).to be_nil
    end

    it 'resolves an ActiveStorage-backed attachment to its blob' do
      expect(helpers.convert_to_active_storage_format(RubyLLM::Attachment.new(blob))).to eq(blob)
    end

    it 'warns and drops an attachment it cannot read' do
      allow(RubyLLM.logger).to receive(:warn)

      expect(helpers.convert_to_active_storage_format('/nonexistent/path.txt')).to be_nil
      expect(RubyLLM.logger).to have_received(:warn).with(/Failed to process attachment/)
    end
  end

  describe '#active_storage_blobs' do
    it 'resolves every ActiveStorage shape' do
      message = message_with_attachment

      expect(helpers.active_storage_blobs(blob)).to eq(blob)
      expect(helpers.active_storage_blobs(message.attachments.first)).to eq(blob)
      expect(helpers.active_storage_blobs(message.attachments)).to eq([blob])
    end

    it 'ignores anything else' do
      expect(helpers.active_storage_blobs('not a blob')).to be_nil
    end
  end

  describe '#plain_text_content' do
    it 'renders rich text as plain text' do
      rich_text = ActionText::RichText.new(body: '<div>Hello <b>world</b></div>')

      expect(helpers.plain_text_content(rich_text)).to eq('Hello world')
    end

    it 'returns plain content untouched' do
      expect(helpers.plain_text_content('Hello')).to eq('Hello')
    end
  end

  describe '#action_text_attachment_sources' do
    it 'is empty for content without a body' do
      expect(helpers.action_text_attachment_sources('plain')).to eq([])
    end

    it 'is empty for a body that carries no attachables' do
      content = Struct.new(:body).new('just a string body')

      expect(helpers.action_text_attachment_sources(content)).to eq([])
    end

    it 'collects the blobs an ActionText body references' do
      rich_text = ActionText::RichText.new(
        body: ActionText::Content.new.append_attachables([blob])
      )

      expect(helpers.action_text_attachment_sources(rich_text)).to eq([blob])
    end
  end

  describe '#action_text_attachable_sources' do
    it 'reads the blob off an attachable that exposes one' do
      attachable = Struct.new(:blob).new(blob)

      expect(helpers.action_text_attachable_sources(attachable)).to eq([blob])
    end

    it 'is empty for an attachable with no blob' do
      expect(helpers.action_text_attachable_sources('nothing')).to eq([])
    end
  end

  describe '#content_attachments?' do
    it 'is true when ActionText carries attachments' do
      expect(helpers.content_attachments?([blob])).to be(true)
    end

    it 'is false when neither ActionText nor ActiveStorage has any' do
      expect(helpers.content_attachments?([])).to be(false)
    end
  end

  describe '#pending_upload_attachable?' do
    it 'is false for nothing, a signed id, or a stored blob' do
      expect(helpers.pending_upload_attachable?(nil)).to be(false)
      expect(helpers.pending_upload_attachable?('signed-id')).to be(false)
      expect(helpers.pending_upload_attachable?(blob)).to be(false)
    end

    it 'is true for the shapes ActiveStorage has not written yet' do
      expect(helpers.pending_upload_attachable?(uploaded_file)).to be(true)
      expect(helpers.pending_upload_attachable?({ io: StringIO.new('x'), filename: 'x.txt' })).to be(true)
      expect(helpers.pending_upload_attachable?(File.new(__FILE__))).to be(true)
      expect(helpers.pending_upload_attachable?(Pathname.new(__FILE__))).to be(true)
    end

    it 'is false for a hash that is not an upload' do
      expect(helpers.pending_upload_attachable?({ key: 'value' })).to be(false)
    end
  end

  describe '#pending_upload_attachment' do
    it 'reads an upload hash' do
      attachment = helpers.pending_upload_attachment({ 'io' => StringIO.new('x'), 'filename' => 'x.txt' })

      expect(attachment.filename).to eq('x.txt')
    end

    it 'wraps anything else directly' do
      expect(helpers.pending_upload_attachment(Pathname.new(__FILE__)).filename).to eq(File.basename(__FILE__))
    end
  end

  describe '#attachment_hash_io and #attachment_hash_filename' do
    it 'accepts symbol and string keys' do
      io = StringIO.new('x')

      expect(helpers.attachment_hash_io({ io: io })).to eq(io)
      expect(helpers.attachment_hash_io({ 'io' => io })).to eq(io)
      expect(helpers.attachment_hash_filename({ filename: :report })).to eq('report')
      expect(helpers.attachment_hash_filename({})).to be_nil
    end
  end

  describe '#instance_of_class?' do
    it 'is false when the class is not loaded' do
      expect(helpers.instance_of_class?('anything', 'Totally::Missing::Class')).to be(false)
    end

    it 'checks against a loaded class' do
      expect(helpers.instance_of_class?('anything', 'String')).to be(true)
    end
  end

  describe '#download_attachment' do
    it 'streams a stored attachment into a tempfile' do
      helpers.instance_variable_set(:@_tempfiles, [])
      message = message_with_attachment

      tempfile = helpers.download_attachment(message.attachments.first)

      expect(tempfile.read).to eq('hello')
      expect(File.extname(tempfile.path)).to eq('.txt')
    end
  end
end
