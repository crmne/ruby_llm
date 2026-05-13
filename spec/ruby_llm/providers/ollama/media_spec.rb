# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Ollama::Media do
  describe '.format_content' do
    it 'raises an actionable error for unsupported document attachments' do
      content = RubyLLM::Content.new('Summarize this file')
      content.add_attachment(StringIO.new('docx bytes'), filename: 'proposal.docx')

      expect do
        described_class.format_content(content)
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      )
    end
  end
end
