# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Azure::Media do
  describe '.format_content' do
    it 'keeps non-PDF documents unsupported for chat completions' do
      content = RubyLLM::Content.new('Summarize this file')
      content.add_attachment(StringIO.new('docx bytes'), filename: 'proposal.docx')

      expect do
        described_class.format_content(content)
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      )
    end

    it 'keeps PDFs unsupported for chat completions' do
      content = RubyLLM::Content.new('Summarize this file')
      content.add_attachment(StringIO.new('pdf bytes'), filename: 'proposal.pdf')

      expect do
        described_class.format_content(content)
      end.to raise_error(RubyLLM::UnsupportedAttachmentError, %r{Unsupported attachment type: application/pdf})
    end
  end
end
