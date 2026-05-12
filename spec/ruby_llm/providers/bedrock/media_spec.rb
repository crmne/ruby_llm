# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Media do
  describe '.render_content' do
    it 'renders supported Office documents as Bedrock document blocks' do
      content = RubyLLM::Content.new('Summarize this file')
      content.add_attachment(StringIO.new('docx bytes'), filename: 'proposal.docx')

      rendered = described_class.render_content(content)

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

    it 'uses Bedrock document blocks for supported text file formats' do
      content = RubyLLM::Content.new('Summarize this file')
      content.add_attachment(StringIO.new('notes'), filename: 'notes.txt')

      rendered = described_class.render_content(content)

      expect(rendered.second).to eq(
        document: {
          format: 'txt',
          name: 'notes',
          source: {
            bytes: Base64.strict_encode64('notes')
          }
        }
      )
    end

    it 'raises an actionable error for document formats Bedrock does not accept' do
      content = RubyLLM::Content.new('Summarize this file')
      content.add_attachment(StringIO.new('pptx bytes'), filename: 'deck.pptx')

      expect do
        described_class.render_content(content)
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.presentationml.presentation}
      )
    end
  end
end
