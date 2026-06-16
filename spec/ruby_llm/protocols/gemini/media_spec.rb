# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Media do
  describe '.format_content' do
    it 'raises a clear error for unsupported rich documents' do
      content = RubyLLM::Content.new('Summarize this file')
      content.add_attachment(StringIO.new('docx bytes'), filename: 'proposal.docx')

      expect do
        described_class.format_content(content)
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      )
    end

    it 'passes PDFs through as native inline data' do
      content = RubyLLM::Content.new('Summarize this file')
      content.add_attachment(StringIO.new('pdf bytes'), filename: 'proposal.pdf')

      parts = described_class.format_content(content)

      expect(parts.first).to eq(text: 'Summarize this file')
      expect(parts.second).to eq(
        inline_data: {
          mime_type: 'application/pdf',
          data: Base64.strict_encode64('pdf bytes')
        }
      )
    end

    it 'keeps text files as text parts' do
      content = RubyLLM::Content.new('Read this file')
      content.add_attachment(StringIO.new('hello'), filename: 'note.txt')

      parts = described_class.format_content(content)

      expect(parts.second).to eq(
        text: "<file name='note.txt' mime_type='text/plain'>hello</file>"
      )
    end
  end

  describe '#build_response_content' do
    it 'parses inline image responses as content attachments' do
      provider = RubyLLM::Protocols::Gemini.allocate
      image_bytes = "\x89PNG\r\n\x1A\n".b

      content = provider.build_response_content(
        [
          {
            'inlineData' => {
              'mimeType' => 'image/png',
              'data' => Base64.strict_encode64(image_bytes)
            }
          }
        ]
      )

      expect(content).to be_a(RubyLLM::Content)
      expect(content.text).to be_nil
      expect(content.attachments.size).to eq(1)

      attachment = content.attachments.first
      expect(attachment.filename).to eq('gemini_attachment_1.png')
      expect(attachment.mime_type).to eq('image/png')
      expect(attachment.content).to eq(image_bytes)
      expect(RubyLLM::Message.new(role: :assistant, content: content).content).to be_a(RubyLLM::Content)
    end
  end
end
