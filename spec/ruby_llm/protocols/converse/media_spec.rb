# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Converse::Media do
  describe '.format_content' do
    it 'renders supported Office documents as Bedrock document blocks' do
      content = RubyLLM::Content.new('Summarize this file')
      content.add_attachment(StringIO.new('docx bytes'), filename: 'proposal.docx')

      rendered = described_class.format_content(content)

      expect(rendered.second).to eq(
        document: {
          format: 'docx',
          name: 'proposal',
          source: {
            bytes: Base64.strict_encode64('docx bytes')
          }
        }
      )
    end

    it 'renders provider-managed documents as S3 document blocks' do
      file = RubyLLM::UploadedFile.new(
        id: 's3://ruby-llm-test/uploads/report.pdf',
        uri: 's3://ruby-llm-test/uploads/report.pdf',
        filename: 'report.pdf',
        mime_type: 'application/pdf'
      )
      content = RubyLLM::Content.new('Summarize this file', file)

      rendered = described_class.format_content(content)

      expect(rendered.second).to eq(
        document: {
          format: 'pdf',
          name: 'report',
          source: {
            s3Location: {
              uri: 's3://ruby-llm-test/uploads/report.pdf'
            }
          }
        }
      )
    end

    it 'keeps text file formats as text blocks' do
      %w[csv txt md html json].each do |extension|
        content = RubyLLM::Content.new('Summarize this file')
        content.add_attachment(StringIO.new('notes'), filename: "notes.#{extension}")

        rendered = described_class.format_content(content)
        attachment = content.attachments.first

        expect(rendered.second).to eq(text: attachment.for_llm)
      end
    end

    it 'raises an actionable error for document formats Bedrock does not accept' do
      content = RubyLLM::Content.new('Summarize this file')
      content.add_attachment(StringIO.new('pptx bytes'), filename: 'deck.pptx')

      expect do
        described_class.format_content(content)
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.presentationml.presentation}
      )
    end
  end
end
