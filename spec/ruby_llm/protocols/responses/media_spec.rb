# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Responses::Media do
  describe '.format_content' do
    it 'formats provider-managed files as input_file file_id parts' do
      file = RubyLLM::UploadedFile.new(id: 'file_123', filename: 'proposal.pdf', mime_type: 'application/pdf')

      formatted = described_class.format_content('Summarize this file', RubyLLM::Attachment.wrap(file))

      expect(formatted.second).to eq(
        type: 'input_file',
        file_id: 'file_123'
      )
    end

    it 'formats PDFs as inline input_file parts' do
      pdf = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/sample.pdf', __dir__))

      formatted = described_class.format_content('Summarize this file', [pdf])

      expect(formatted.second[:type]).to eq('input_file')
      expect(formatted.second[:filename]).to eq('sample.pdf')
      expect(formatted.second[:file_data]).to start_with('data:application/pdf;base64,')
    end

    %w[sample.docx sample.xlsx].each do |filename|
      it "formats #{File.extname(filename).delete_prefix('.')} documents as inline input_file parts" do
        document = RubyLLM::Attachment.new(File.expand_path("../../../fixtures/#{filename}", __dir__))

        formatted = described_class.format_content('Summarize this file', [document])

        expect(formatted.second[:type]).to eq('input_file')
        expect(formatted.second[:filename]).to eq(filename)
        expect(formatted.second[:file_data]).to start_with("data:#{document.mime_type};base64,")
      end
    end

    it 'keeps text files inline' do
      text = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.txt', __dir__))

      formatted = described_class.format_content('Summarize this file', [text])

      expect(formatted.second[:type]).to eq('input_text')
    end

    it 'still rejects attachments the API cannot take' do
      audio = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.wav', __dir__))

      expect { described_class.format_content('Listen', [audio]) }
        .to raise_error(RubyLLM::UnsupportedAttachmentError, %r{audio/wav})
    end
  end
end
