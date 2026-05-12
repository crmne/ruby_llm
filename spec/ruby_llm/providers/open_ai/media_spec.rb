# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Media do
  describe '.format_content' do
    it 'serializes raw hash payloads to JSON strings' do
      raw = RubyLLM::Content::Raw.new({ country: 'France' })

      formatted = described_class.format_content(raw)

      expect(formatted).to eq('{"country":"France"}')
    end

    it 'passes through raw array payloads without serialization' do
      payload = [{ type: 'text', text: 'Hello' }]
      raw = RubyLLM::Content::Raw.new(payload)

      formatted = described_class.format_content(raw)

      expect(formatted).to eq(payload)
    end

    it 'formats arbitrary files as file parts when the provider opts in' do
      content = RubyLLM::Content.new('Summarize this file')
      content.add_attachment(StringIO.new('docx bytes'), filename: 'proposal.docx')

      formatted = described_class.format_content(content, document_attachments: :all)

      expect(formatted.second).to eq(
        type: 'file',
        file: {
          filename: 'proposal.docx',
          file_data: "data:application/vnd.openxmlformats-officedocument.wordprocessingml.document;base64,#{Base64.strict_encode64('docx bytes')}" # rubocop:disable Layout/LineLength
        }
      )
    end

    it 'raises an actionable error for arbitrary files unless the provider opts in' do
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
