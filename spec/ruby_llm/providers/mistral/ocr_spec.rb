# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Mistral::OCR do
  describe '.render_ocr_payload' do
    it 'sends remote documents as document_url references' do
      payload = described_class.render_ocr_payload('https://example.com/report.pdf', model: 'mistral-ocr-latest')

      expect(payload).to eq(
        model: 'mistral-ocr-latest',
        document: { type: 'document_url', document_url: 'https://example.com/report.pdf' }
      )
    end

    it 'inlines local documents as base64 data URIs' do
      pdf_path = File.expand_path('../../../fixtures/sample.pdf', __dir__)

      payload = described_class.render_ocr_payload(pdf_path, model: 'mistral-ocr-latest')

      expect(payload[:document][:type]).to eq('document_url')
      expect(payload[:document][:document_url]).to start_with('data:application/pdf;base64,')
    end

    it 'sends images through the image_url variant' do
      image_path = File.expand_path('../../../fixtures/ruby.png', __dir__)

      payload = described_class.render_ocr_payload(image_path, model: 'mistral-ocr-latest')

      expect(payload[:document][:type]).to eq('image_url')
      expect(payload[:document][:image_url]).to start_with('data:image/png;base64,')
    end

    it 'merges options into the payload in Mistral vocabulary' do
      payload = described_class.render_ocr_payload(
        'https://example.com/report.pdf',
        model: 'mistral-ocr-latest',
        pages: [0],
        provider_options: { include_image_base64: true, table_format: 'html' }
      )

      expect(payload[:pages]).to eq([0])
      expect(payload[:include_image_base64]).to be(true)
      expect(payload[:table_format]).to eq('html')
    end
  end

  describe '.parse_ocr_response' do
    it 'builds an OCR result from pages, model, and usage_info' do
      body = {
        'pages' => [
          { 'index' => 0, 'markdown' => '# Hello', 'images' => [], 'tables' => [] },
          { 'index' => 1, 'markdown' => 'World', 'images' => [], 'tables' => [] }
        ],
        'model' => 'mistral-ocr-latest',
        'usage_info' => { 'pages_processed' => 2, 'doc_size_bytes' => 123 }
      }
      response = instance_double(Faraday::Response, body: body)

      ocr = described_class.parse_ocr_response(response, model: 'mistral-ocr-latest')

      expect(ocr.pages.map(&:index)).to eq([0, 1])
      expect(ocr.pages.first.markdown).to eq('# Hello')
      expect(ocr.markdown).to eq("# Hello\n\nWorld")
      expect(ocr.model).to eq('mistral-ocr-latest')
      expect(ocr.usage).to eq('pages_processed' => 2, 'doc_size_bytes' => 123)
      expect(ocr.raw).to eq(body)
    end
  end
end
