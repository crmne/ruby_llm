# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::Media do
  describe '.format_content' do
    it 'returns the content string unchanged when there are no attachments' do
      formatted = described_class.format_content('Hello')

      expect(formatted).to eq('Hello')
    end

    it 'formats arbitrary files as file parts when the provider opts in' do
      attachment = RubyLLM::Attachment.new(StringIO.new('docx bytes'), filename: 'proposal.docx')

      formatted = described_class.format_content('Summarize this file', [attachment], document_attachments: :all)

      expect(formatted.second).to eq(
        type: 'file',
        file: {
          filename: 'proposal.docx',
          file_data: "data:application/vnd.openxmlformats-officedocument.wordprocessingml.document;base64,#{Base64.strict_encode64('docx bytes')}" # rubocop:disable Layout/LineLength
        }
      )
    end

    it 'formats provider-managed files as file_id parts when file attachments are enabled' do
      file = RubyLLM::UploadedFile.new(id: 'file_123', filename: 'proposal.pdf', mime_type: 'application/pdf')

      formatted = described_class.format_content('Summarize this file', RubyLLM::Attachment.wrap(file))

      expect(formatted.second).to eq(
        type: 'file',
        file: {
          file_id: 'file_123'
        }
      )
    end

    it 'keeps provider-managed file parts disabled when the provider opts out' do
      file = RubyLLM::UploadedFile.new(id: 'file_123', filename: 'proposal.pdf', mime_type: 'application/pdf')

      expect do
        described_class.format_content('Summarize this file', RubyLLM::Attachment.wrap(file),
                                       document_attachments: :none)
      end.to raise_error(RubyLLM::UnsupportedAttachmentError, %r{application/pdf})
    end

    it 'raises an actionable error for arbitrary files unless the provider opts in' do
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
