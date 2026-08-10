# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Media do
  describe '.format_content' do
    it 'raises a clear error for unsupported rich documents' do
      attachment = RubyLLM::Attachment.new(StringIO.new('docx bytes'), filename: 'proposal.docx')

      expect do
        described_class.format_content('Summarize this file', [attachment])
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      )
    end

    it 'passes PDFs through as native inline data' do
      attachment = RubyLLM::Attachment.new(StringIO.new('pdf bytes'), filename: 'proposal.pdf')

      parts = described_class.format_content('Summarize this file', [attachment])

      expect(parts.first).to eq(text: 'Summarize this file')
      expect(parts.second).to eq(
        inline_data: {
          mime_type: 'application/pdf',
          data: Base64.strict_encode64('pdf bytes')
        }
      )
    end

    it 'keeps text files as text parts' do
      attachment = RubyLLM::Attachment.new(StringIO.new('hello'), filename: 'note.txt')

      parts = described_class.format_content('Read this file', [attachment])

      expect(parts.second).to eq(
        text: "<file name='note.txt' mime_type='text/plain'>hello</file>"
      )
    end

    it 'formats provider-managed files as file_data parts' do
      file = RubyLLM::UploadedFile.new(
        id: 'files/abc',
        filename: 'video.mp4',
        mime_type: 'video/mp4',
        uri: 'https://generativelanguage.googleapis.com/v1beta/files/abc'
      )
      parts = described_class.format_content('Watch this', RubyLLM::Attachment.wrap(file))

      expect(parts.second).to eq(
        file_data: {
          mime_type: 'video/mp4',
          file_uri: 'https://generativelanguage.googleapis.com/v1beta/files/abc'
        }
      )
    end
  end

  describe '#build_response_content' do
    it 'parses inline image responses as a text and attachments pair' do
      provider = RubyLLM::Protocols::Gemini.allocate
      image_bytes = "\x89PNG\r\n\x1A\n".b

      text, attachments = provider.build_response_content(
        [
          {
            'inlineData' => {
              'mimeType' => 'image/png',
              'data' => Base64.strict_encode64(image_bytes)
            }
          }
        ]
      )

      expect(text).to be_nil
      expect(attachments.size).to eq(1)

      attachment = attachments.first
      expect(attachment.filename).to eq('gemini_attachment_1.png')
      expect(attachment.mime_type).to eq('image/png')
      expect(attachment.content).to eq(image_bytes)

      message = RubyLLM::Message.new(role: :assistant, content: text, attachments: attachments)
      expect(message.content).to be_nil
      expect(message.attachments).to eq(attachments)
    end
  end

  describe '#build_response_content part shapes' do
    let(:provider) { RubyLLM::Protocols::Gemini.allocate }

    it 'joins text parts and reports no attachments' do
      text, attachments = provider.build_response_content([{ 'text' => 'one ' }, { 'text' => 'two' }])

      expect(text).to eq('one two')
      expect(attachments).to be_empty
    end

    it 'ignores parts it does not recognize' do
      expect(provider.build_response_content([{ 'functionCall' => {} }])).to eq([nil, []])
    end

    it 'builds an attachment from a fileData part' do
      text, attachments = provider.build_response_content(
        [{ 'fileData' => { 'fileUri' => 'https://files.example/report', 'mimeType' => 'application/pdf' } }]
      )

      expect(text).to be_nil
      expect(attachments.first.filename).to eq('gemini_attachment_1.pdf')
    end

    it 'prefers the filename the response carries' do
      _text, attachments = provider.build_response_content(
        [{ 'fileData' => { 'fileUri' => 'https://files.example/x', 'filename' => 'report.pdf' } }]
      )

      expect(attachments.first.filename).to eq('report.pdf')
    end

    it 'skips a fileData part with no URI' do
      expect(provider.build_response_content([{ 'fileData' => {} }])).to eq([nil, []])
    end

    it 'skips an inlineData part with no data' do
      expect(provider.build_response_content([{ 'inlineData' => { 'mimeType' => 'image/png' } }])).to eq([nil, []])
    end
  end

  describe '#attachment_filename' do
    let(:provider) { RubyLLM::Protocols::Gemini.allocate }

    it 'falls back to an extensionless name without a mime type' do
      expect(provider.attachment_filename(nil, 0)).to eq('gemini_attachment_1')
    end

    it 'normalizes the extensions Gemini reports' do
      expect(provider.attachment_filename('image/jpeg', 0)).to eq('gemini_attachment_1.jpg')
      expect(provider.attachment_filename('text/plain', 1)).to eq('gemini_attachment_2.txt')
      expect(provider.attachment_filename('image/svg+xml', 2)).to eq('gemini_attachment_3.svg.xml')
    end
  end

  describe '.format_content without text' do
    it 'sends attachments without any text' do
      attachment = RubyLLM::Attachment.new(StringIO.new('pdf bytes'), filename: 'proposal.pdf')

      parts = described_class.format_content(nil, [attachment])

      expect(parts.length).to eq(1)
      expect(parts.first).to have_key(:inline_data)
    end
  end

  describe '.format_file_data' do
    it 'falls back to the provider file id when there is no URI' do
      file = RubyLLM::UploadedFile.new(
        id: 'file_1', provider: 'gemini', filename: 'clip.mp4', mime_type: 'video/mp4'
      )

      expect(described_class.format_file_data(RubyLLM::Attachment.new(file))).to eq(
        file_data: { mime_type: 'video/mp4', file_uri: 'file_1' }
      )
    end
  end
end
