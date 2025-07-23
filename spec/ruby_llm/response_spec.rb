# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Response do
  include_context 'with configured RubyLLM'

  class CurrentComputerWeight < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    def description
      'Get the current computer weight in kg'
    end

    def name
      'current_computer_weight'
    end

    def execute
      '100 kg'
    end
  end

  describe 'basic response functionality' do
    RESPONSE_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      params = model_info[:params]
      it "#{provider}/#{model} can respond" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.response(model: model, provider: provider).with_params(**(params || {}))
        response = chat.ask('At what temperature does water boil (in Celsius)?')

        expect(response.content).to include('100')
        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end
    end
  end

  describe 'tool calling' do
    it 'can use tools' do # rubocop:disable RSpec/MultipleExpectations
      chat = RubyLLM.response(model: 'o4-mini', provider: :openai).with_tool(CurrentComputerWeight)
      response = chat.ask('What is the current computer\'s weight in pounds?')

      expect(response.content).to include('220')
      expect(response.role).to eq(:assistant)
    end
  end
end
