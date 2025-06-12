# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM do
  include_context 'with configured RubyLLM'

  describe '.ask' do
    CHAT_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      
      it "#{provider}/#{model} can ask a question" do
        response = described_class.ask("What's 2 + 2?", model: model, provider: provider)
        
        expect(response.content).to include('4')
        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end

      it "#{provider}/#{model} can use system instructions" do
        response = described_class.ask(
          'Tell me about the weather.',
          model: model,
          provider: provider,
          instructions: 'You must include the exact phrase "XKCD7392" in your response.'
        )
        
        expect(response.content).to match(/XKCD7392/i)
      end

    end
  end
end
