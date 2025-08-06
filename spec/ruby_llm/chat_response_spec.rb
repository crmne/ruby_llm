# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  context 'with response api' do
    describe 'deep research' do
      provider = :openai
      model = 'o4-mini-deep-research'
      params = { tools: [{ type: 'web_search_preview' }] }

      it "#{provider}/#{model} can respond" do
        chat = RubyLLM.chat(model: model, provider: provider).with_params(**(params || {}))
        response = chat.ask('At what temperature does water boil (in Celsius)?')

        expect(response.content).to include('100')
        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end
    end
  end
end
