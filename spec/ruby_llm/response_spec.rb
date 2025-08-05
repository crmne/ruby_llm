# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  context 'response' do
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
      provider = :openai
      model = 'o4-mini-deep-research'
      params = { tools: [{ type: 'web_search_preview' }] }

      it "#{provider}/#{model} can respond" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider).with_params(**(params || {}))
        response = chat.ask('At what temperature does water boil (in Celsius)?')

        expect(response.content).to include('100')
        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end
    end

    describe 'tool calling' do
      it 'can use tools' do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: 'o4-mini', provider: :openai).with_tool(CurrentComputerWeight)
        response = chat.ask('What is the current computer\'s weight in pounds?')

        expect(response.content).to include('220')
        expect(response.role).to eq(:assistant)
      end
    end
  end
end