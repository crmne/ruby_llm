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
