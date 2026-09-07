# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Ollama::Media do
  describe '.format_content' do
    it 'encodes audio attachments in the released Ollama input_audio format' do
      attachment = RubyLLM::Attachment.new(StringIO.new('wav bytes'), filename: 'meeting.wav')

      content = described_class.format_content('Summarize this recording', [attachment])

      expect(content).to eq(
        [
          { type: 'text', text: 'Summarize this recording' },
          { type: 'input_audio', input_audio: { data: Base64.strict_encode64('wav bytes'), format: 'wav' } }
        ]
      )
    end

    it 'raises an actionable error for unsupported document attachments' do
      attachment = RubyLLM::Attachment.new(StringIO.new('docx bytes'), filename: 'proposal.docx')

      expect do
        described_class.format_content('Summarize this file', [attachment])
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      )
    end
  end
end
