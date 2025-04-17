# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:pdf_path) { File.expand_path('../fixtures/sample.pdf', __dir__) }

  pdf_models = %w[claude-3-5-haiku-20241022 gemini-2.0-flash].freeze

  describe 'pdf model' do
    pdf_models.each do |model|
      provider = RubyLLM::Models.provider_for(model).slug
      it "#{provider}/#{model} understands PDFs" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model)
        response = chat.ask('Summarize this document', with: { pdf: pdf_path })
        expect(response.content).not_to be_empty

        response = chat.ask 'go on'
        expect(response.content).not_to be_empty
      end

      it "#{provider}/#{model} handles multiple PDFs" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model)
        # Using same file twice for testing
        response = chat.ask('Compare these documents', with: { pdf: [pdf_path, pdf_path] })
        expect(response.content).not_to be_empty

        response = chat.ask 'go on'
        expect(response.content).not_to be_empty
      end
    end
  end
end
