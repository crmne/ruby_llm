# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Azure::Media do
  describe '.format_content' do
    it 'sends the media resolution as image detail' do
      image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__), resolution: :low)

      formatted = described_class.format_content('Describe this', [image])

      expect(formatted.second[:image_url][:detail]).to eq('low')
    end

    it 'keeps non-PDF documents unsupported for chat completions' do
      attachment = RubyLLM::Attachment.new(StringIO.new('docx bytes'), filename: 'proposal.docx')

      expect do
        described_class.format_content('Summarize this file', [attachment])
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      )
    end

    it 'keeps PDFs unsupported for chat completions' do
      attachment = RubyLLM::Attachment.new(StringIO.new('pdf bytes'), filename: 'proposal.pdf')

      expect do
        described_class.format_content('Summarize this file', [attachment])
      end.to raise_error(RubyLLM::UnsupportedAttachmentError, %r{Unsupported attachment type: application/pdf})
    end
  end
end
