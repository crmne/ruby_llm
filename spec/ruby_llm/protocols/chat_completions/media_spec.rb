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

    it 'maps low resolution to low image detail' do
      image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__), resolution: :low)

      formatted = described_class.format_content('Describe this', [image])

      expect(formatted.second[:image_url][:detail]).to eq('low')
    end

    it 'maps medium resolution to high image detail even when original detail is enabled' do
      image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__), resolution: :medium)

      formatted = described_class.format_content('Describe this', [image], original_detail: true)

      expect(formatted.second[:image_url][:detail]).to eq('high')
    end

    { openai: 'original', azure: 'original', xai: 'high', openrouter: 'high' }.each do |provider_name, detail|
      it "maps ultra high resolution to #{detail} image detail for #{provider_name}" do
        provider = instance_double(RubyLLM::Provider, slug: provider_name.to_s, config: RubyLLM.config, connection: nil)
        protocol = RubyLLM::Protocols::ChatCompletions.new(provider)
        image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__),
                                        resolution: :ultra_high)

        formatted = protocol.send(:format_content, 'Read the small print', [image])

        expect(formatted.second[:image_url][:detail]).to eq(detail)
      end
    end

    it 'omits image detail when no resolution is set' do
      image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__))

      formatted = described_class.format_content('Describe this', [image])

      expect(formatted.second[:image_url]).not_to have_key(:detail)
    end
  end
end
