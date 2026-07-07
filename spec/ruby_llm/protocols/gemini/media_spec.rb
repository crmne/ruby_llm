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
end
