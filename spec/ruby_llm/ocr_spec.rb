# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::OCR, :live do
  let(:pdf_path) { File.expand_path('../fixtures/sample.pdf', __dir__) }

  describe '#pages', live: false do
    it 'preserves a normalized page and its unmodified provider data' do
      raw = { 'index' => 0, 'markdown' => { 'content' => '# Ruby' } }
      page = described_class::Page.new(index: 0, markdown: '# Ruby', raw: raw)
      result = described_class.new(pages: [page], model: model_for(:cohere, :ocr))

      expect(result.pages.first).to equal(page)
      expect(result.pages.first.raw).to equal(raw)
      expect(result.markdown).to eq('# Ruby')
    end

    it 'continues converting hash pages with their original metadata' do
      raw = { 'markdown' => '# Ruby', 'images' => [], 'tables' => [] }
      result = described_class.new(pages: [raw], model: model_for(:mistral, :ocr))

      expect(result.pages.first).to have_attributes(index: 0, markdown: '# Ruby', images: [], tables: [])
      expect(result.pages.first.raw).to equal(raw)
    end
  end

  describe 'basic functionality' do
    it "mistral/#{model_for(:mistral, :ocr)} extracts markdown from a PDF" do
      ocr = RubyLLM.ocr(pdf_path, model: model_for(:mistral, :ocr), provider: :mistral)

      expect(ocr.pages).not_to be_empty
      expect(ocr.pages.first.index).to eq(0)
      expect(ocr.markdown).to match(/sample pdf/i)
      expect(ocr.model).to eq(model_for(:mistral, :ocr))
    end

    it 'uses the default OCR model when none is given' do
      ocr = RubyLLM.ocr(pdf_path)

      expect(ocr.model).to eq(model_for(:mistral, :ocr))
      expect(ocr.markdown).to match(/sample pdf/i)
    end

    it "mistral/#{model_for(:mistral, :ocr)} passes options through in provider vocabulary" do
      ocr = RubyLLM.ocr(pdf_path, model: model_for(:mistral, :ocr), provider: :mistral, pages: [0])

      expect(ocr.pages.length).to eq(1)
      expect(ocr.usage['pages_processed']).to eq(1)
    end

    it 'raises a clear error on providers without OCR support' do
      expect do
        RubyLLM.ocr(pdf_path, model: model_for(:openai), provider: :openai)
      end.to raise_error(RubyLLM::Error, /doesn't support OCR/)
    end

    it 'validates model existence' do
      expect do
        RubyLLM.ocr(pdf_path, model: 'invalid-ocr-model')
      end.to raise_error(RubyLLM::ModelNotFoundError)
    end
  end
end
