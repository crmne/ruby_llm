# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  chat_models = %w[claude-3-5-haiku-20241022
                   anthropic.claude-3-5-haiku-20241022-v1:0
                   gemini-2.0-flash
                   deepseek-chat
                   gpt-4.1-nano].freeze

  describe 'basic chat functionality' do
    chat_models.each do |model|
      provider = RubyLLM::Models.provider_for(model).slug
      it "#{provider}/#{model} can have a basic conversation" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model)
        response = chat.ask("What's 2 + 2?")

        expect(response.content).to include('4')
        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end

      it "#{provider}/#{model} can handle multi-turn conversations" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model)

        first = chat.ask("Who was Ruby's creator?")
        expect(first.content).to include('Matz')

        followup = chat.ask('What year did he create Ruby?')
        expect(followup.content).to include('199')
      end

      it "#{provider}/#{model} successfully uses the system prompt" do
        chat = RubyLLM.chat(model: model).with_temperature(0.0)

        # Use a distinctive and unusual instruction that wouldn't happen naturally
        chat.with_instructions 'You must include the exact phrase "XKCD7392" somewhere in your response.'

        response = chat.ask('Tell me about the weather.')
        expect(response.content).to include('XKCD7392')
      end

      it "#{provider}/#{model} replaces previous system messages when replace: true" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model).with_temperature(0.0)

        # Use a distinctive and unusual instruction that wouldn't happen naturally
        chat.with_instructions 'You must include the exact phrase "XKCD7392" somewhere in your response.'

        response = chat.ask('Tell me about the weather.')
        expect(response.content).to include('XKCD7392')

        # Test ability to follow multiple instructions with another unique marker
        chat.with_instructions 'You must include the exact phrase "PURPLE-ELEPHANT-42" somewhere in your response.',
                               replace: true

        response = chat.ask('What are some good books?')
        expect(response.content).not_to include('XKCD7392')
        expect(response.content).to include('PURPLE-ELEPHANT-42')
      end
    end
  end
end
