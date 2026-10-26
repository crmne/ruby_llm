# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Responses::Media do
  describe '.render_content' do
    it 'formats provider-managed files as input_file file_id parts' do
      file = RubyLLM::UploadedFile.new(id: 'file_123', filename: 'proposal.pdf', mime_type: 'application/pdf')

      formatted = described_class.render_content('Summarize this file', RubyLLM::Attachment.wrap(file))

      expect(formatted.second).to eq(
        type: 'input_file',
        file_id: 'file_123'
      )
    end

    it 'formats PDFs as inline input_file parts' do
      pdf = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/sample.pdf', __dir__))

      formatted = described_class.render_content('Summarize this file', [pdf])

      expect(formatted.second[:type]).to eq('input_file')
      expect(formatted.second[:filename]).to eq('sample.pdf')
      expect(formatted.second[:file_data]).to start_with('data:application/pdf;base64,')
    end

    %w[sample.docx sample.xlsx].each do |filename|
      it "formats #{File.extname(filename).delete_prefix('.')} documents as inline input_file parts" do
        document = RubyLLM::Attachment.new(File.expand_path("../../../fixtures/#{filename}", __dir__))

        formatted = described_class.render_content('Summarize this file', [document])

        expect(formatted.second[:type]).to eq('input_file')
        expect(formatted.second[:filename]).to eq(filename)
        expect(formatted.second[:file_data]).to start_with("data:#{document.mime_type};base64,")
      end
    end

    [
      RubyLLM::Providers::OpenAI, RubyLLM::Providers::Azure, RubyLLM::Providers::XAI,
      RubyLLM::Providers::OpenRouter, RubyLLM::Providers::Meta
    ].each do |provider_class|
      it "passes document URLs through as input_file file_url parts for #{provider_class}" do
        protocol = provider_class.protocols.fetch(:responses).new(provider_class.allocate)
        url = 'https://files.example/signed/report.pdf?signature=abc'
        document = RubyLLM::Attachment.new(url, filename: 'report.pdf')

        formatted = protocol.send(:render_content, 'Summarize this file', [document])

        expect(formatted.second).to eq(type: 'input_file', file_url: url)
        expect(a_request(:get, url)).not_to have_been_made
      end
    end

    it 'downloads document URLs into file_data where the provider does not fetch them' do
      url = 'https://files.example/report.pdf'
      stub_request(:get, url).to_return(status: 200, body: '%PDF-1.4', headers: { 'Content-Type' => 'application/pdf' })
      protocol = RubyLLM::Providers::Bedrock::Mantle::Responses.allocate

      formatted = protocol.send(:render_content, 'Summarize this file', [RubyLLM::Attachment.new(url)])

      expect(formatted.second).to eq(type: 'input_file', filename: 'report.pdf',
                                     file_data: "data:application/pdf;base64,#{Base64.strict_encode64('%PDF-1.4')}")
    end

    it 'keeps local documents inline where the provider fetches document URLs' do
      protocol = RubyLLM::Providers::OpenAI::Responses.new(RubyLLM::Providers::OpenAI.allocate)
      pdf = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/sample.pdf', __dir__))

      formatted = protocol.send(:render_content, 'Summarize this file', [pdf])

      expect(formatted.second.keys).to eq(%i[type filename file_data])
    end

    it 'keeps image URLs as input_image parts where the provider fetches document URLs' do
      protocol = RubyLLM::Providers::OpenAI::Responses.new(RubyLLM::Providers::OpenAI.allocate)
      image = RubyLLM::Attachment.new('https://files.example/ruby.png')

      formatted = protocol.send(:render_content, 'Describe this', [image])

      expect(formatted.second).to eq(type: 'input_image', image_url: 'https://files.example/ruby.png')
    end

    it 'keeps text files inline' do
      text = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.txt', __dir__))

      formatted = described_class.render_content('Summarize this file', [text])

      expect(formatted.second[:type]).to eq('input_text')
    end

    it 'still rejects attachments the API cannot take' do
      audio = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.wav', __dir__))

      expect { described_class.render_content('Listen', [audio]) }
        .to raise_error(RubyLLM::UnsupportedAttachmentError, %r{audio/wav})
    end

    it 'maps low resolution to low image detail' do
      image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__), resolution: :low)

      formatted = described_class.render_content('Describe this', [image])

      expect(formatted.second[:detail]).to eq('low')
    end

    it 'keeps ultra high resolution at high detail even when original detail is enabled' do
      image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__), resolution: :ultra_high)

      protocol = RubyLLM::Protocols::Responses.new(RubyLLM::Providers::OpenAI.allocate)
      formatted = protocol.send(:render_content, 'Describe this', [image])

      expect(formatted.second[:detail]).to eq('high')
    end

    {
      RubyLLM::Providers::OpenAI => 'original', RubyLLM::Providers::Azure => 'original',
      RubyLLM::Providers::XAI => 'high', RubyLLM::Providers::OpenRouter => 'high'
    }.each do |provider_class, detail|
      it "maps original resolution to #{detail} image detail for #{provider_class}" do
        protocol = provider_class.protocols.fetch(:responses).new(provider_class.allocate)
        image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__), resolution: :original)

        formatted = protocol.send(:render_content, 'Read the small print', [image])

        expect(formatted.second[:detail]).to eq(detail)
      end
    end

    it 'omits image detail when no resolution is set' do
      image = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__))

      formatted = described_class.render_content('Describe this', [image])

      expect(formatted.second).not_to have_key(:detail)
    end
  end
end
