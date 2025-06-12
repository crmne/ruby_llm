# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe 'pdf model' do
    shared_examples 'PDF_MODELS' do |model, provider|
      it "#{provider}/#{model} understands PDFs" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('Summarize this document', with: { pdf: pdf_locator })
        expect(response.content).not_to be_empty

        response = chat.ask 'go on'
        expect(response.content).not_to be_empty
      end

      it "#{provider}/#{model} handles multiple PDFs" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
        # Using same file twice for testing
        response = chat.ask('Compare these documents', with: { pdf: [pdf_locator, pdf_locator] })
        expect(response.content).not_to be_empty

        response = chat.ask 'go on'
        expect(response.content).not_to be_empty
      end
    end

    PDF_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]

      context 'with Paths' do
        let(:pdf_locator) { File.expand_path('../fixtures/sample.pdf', __dir__) }

        it_behaves_like 'PDF_MODELS', model, provider
      end

      context 'with URLs' do
        let(:pdf_locator) { 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf' }

        it_behaves_like 'PDF_MODELS', model, provider
      end
    end
  end
end
