# frozen_string_literal: true

require 'spec_helper'
require 'dotenv/load'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe 'basic chat functionality' do
    [
      'claude-3-5-haiku-20241022',
      'gemini-2.0-flash',
      'deepseek-chat',
      'gpt-4o-mini',
      'sonar'
    ].each do |model|
      it "#{model} can have a basic conversation" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model)
        response = chat.ask("What's 2 + 2?")

        expect(response.content).to include('4')
        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end

      it "#{model} can handle multi-turn conversations" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model)

        first = chat.ask("Who was Ruby's creator?")
        expect(first.content).to include('Matz')

        followup = chat.ask('What year did he create Ruby?')
        expect(followup.content).to include('199')
      end
    end
  end
end
