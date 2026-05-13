# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Gemini::Media do
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
end
