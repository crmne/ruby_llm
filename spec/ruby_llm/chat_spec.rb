# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe 'basic chat functionality' do
    CHAT_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can have a basic conversation" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask("What's 2 + 2?")

        expect(response.content).to include('4')
        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end

      it "#{provider}/#{model} can handle multi-turn conversations" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)

        first = chat.ask("Who was Ruby's creator?")
        expect(first.content).to include('Matz')

        followup = chat.ask('What year did he create Ruby?')
        expect(followup.content).to include('199')
      end

      it "#{provider}/#{model} successfully uses the system prompt" do
        chat = RubyLLM.chat(model: model, provider: provider).with_temperature(0.0)

        # Use a distinctive and unusual instruction that wouldn't happen naturally
        chat.with_instructions 'You must include the exact phrase "XKCD7392" somewhere in your response.'

        response = chat.ask('Tell me about the weather.')
        expect(response.content).to match(/XKCD7392/i)
      end

      it "#{provider}/#{model} replaces previous system messages when replace: true" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider).with_temperature(0.0)

        # Use a distinctive and unusual instruction that wouldn't happen naturally
        chat.with_instructions 'You must include the exact phrase "XKCD7392" somewhere in your response.'

        response = chat.ask('Tell me about the weather.')
        expect(response.content).to match(/XKCD7392/i)

        # Test ability to follow multiple instructions with another unique marker
        chat.with_instructions 'You must include the exact phrase "PURPLE-ELEPHANT-42" somewhere in your response.',
                               replace: true

        response = chat.ask('What are some good books?')
        expect(response.content).not_to match(/XKCD7392/i)
        expect(response.content).to match(/PURPLE-ELEPHANT-42/i)
      end
    end
  end

  describe 'change model on the fly' do
    CHAT_MODELS.first(3).combination(2).each do |first, second|
      it "between #{first[:provider]}/#{first[:model]} and #{second[:provider]}/#{second[:model]}" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: first[:model], provider: first[:provider])
        response = chat.ask("What's 2 + 2?")

        expect(response.content).to include('4')
        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive

        chat.with_model(second[:model], provider: second[:provider])
        response = chat.ask('and 4 + 4?')

        expect(response.content).to include('8')
        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end
    end
  end
end
