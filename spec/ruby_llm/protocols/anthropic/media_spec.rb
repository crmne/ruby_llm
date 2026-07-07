# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic::Media do
  describe '.format_content' do
    let(:pdf_path) { File.join('spec', 'fixtures', 'sample.pdf') }

    it 'serializes text with attachments into Anthropic blocks' do
      attachments = RubyLLM::Attachment.wrap(pdf_path)

      blocks = described_class.format_content('Summarize this', attachments)

      expect(blocks).to all(be_a(Hash))
      expect(blocks.first).to include(type: 'text', text: 'Summarize this')
      document_block = blocks.detect { |block| block[:type] == 'document' }
      expect(document_block).to be_present
      expect(document_block[:source]).to include(type: 'base64', media_type: 'application/pdf')
      expect(document_block[:source][:data]).to be_present
    end

    it 'raises an actionable error for unsupported Office documents' do
      attachment = RubyLLM::Attachment.new(StringIO.new('docx bytes'), filename: 'proposal.docx')

      expect do
        described_class.format_content('Summarize this file', [attachment])
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      )
    end

    it 'formats provider-managed PDFs as document file sources' do
      file = RubyLLM::UploadedFile.new(id: 'file_123', filename: 'proposal.pdf', mime_type: 'application/pdf')

      blocks = described_class.format_content('Summarize this', RubyLLM::Attachment.wrap(file), citations: true)

      expect(blocks.second).to eq(
        type: 'document',
        source: {
          type: 'file',
          file_id: 'file_123'
        },
        title: 'proposal.pdf',
        citations: { enabled: true }
      )
    end

    it 'formats provider-managed images as image file sources' do
      file = RubyLLM::UploadedFile.new(id: 'file_456', filename: 'chart.png', mime_type: 'image/png')

      blocks = described_class.format_content('Describe this', RubyLLM::Attachment.wrap(file))

      expect(blocks.second).to eq(
        type: 'image',
        source: {
          type: 'file',
          file_id: 'file_456'
        }
      )
    end
  end
end
