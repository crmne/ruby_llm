# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:pdf_path) { File.expand_path('../fixtures/sample.pdf', __dir__) }

  describe 'pdf model' do
    PDF_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} understands PDFs" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('Summarize this document', with: { pdf: pdf_path })
        expect(response.content).not_to be_empty

        response = chat.ask 'go on'
        expect(response.content).not_to be_empty
      end

      it "#{provider}/#{model} handles multiple PDFs" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
        # Using same file twice for testing
        response = chat.ask('Compare these documents', with: { pdf: [pdf_path, pdf_path] })
        expect(response.content).not_to be_empty

        response = chat.ask 'go on'
        expect(response.content).not_to be_empty
      end
    end
  end
end
