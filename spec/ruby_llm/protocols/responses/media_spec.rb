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

    it 'maps low resolution to low image detail' do
      image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__), resolution: :low)

      formatted = described_class.format_content('Describe this', [image])

      expect(formatted.second[:detail]).to eq('low')
    end

    it 'keeps ultra high resolution at high detail unless original detail is enabled' do
      image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__), resolution: :ultra_high)

      formatted = described_class.format_content('Describe this', [image])

      expect(formatted.second[:detail]).to eq('high')
    end

    { openai: 'original', azure: 'original', xai: 'high', openrouter: 'high' }.each do |provider_name, detail|
      it "maps ultra high resolution to #{detail} image detail for #{provider_name}" do
        provider = instance_double(RubyLLM::Provider, slug: provider_name.to_s, config: RubyLLM.config, connection: nil)
        protocol = RubyLLM::Protocols::Responses.new(provider)
        image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__),
                                        resolution: :ultra_high)

        formatted = protocol.send(:format_content, 'Read the small print', [image])

        expect(formatted.second[:detail]).to eq(detail)
      end
    end

    it 'omits image detail when no resolution is set' do
      image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__))

      formatted = described_class.format_content('Describe this', [image])

      expect(formatted.second).not_to have_key(:detail)
    end
  end
end
