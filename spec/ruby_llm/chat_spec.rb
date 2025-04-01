# frozen_string_literal: true

require 'spec_helper'
require 'dotenv/load'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe 'basic chat functionality' do
    [
      ['claude-3-5-haiku-20241022', nil],
      ['gemini-2.0-flash', nil],
      ['deepseek-chat', nil],
      ['gpt-4o-mini', nil],
      %w[claude-3-5-haiku bedrock]
    ].each do |model, provider|
      provider_suffix = provider ? " with #{provider}" : ''
      it "#{model} can have a basic conversation#{provider_suffix}" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask("What's 2 + 2?")

        expect(response.content).to include('4')
        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end

      it "#{model} can handle multi-turn conversations#{provider_suffix}" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)

        first = chat.ask("Who was Ruby's creator?")
        expect(first.content).to include('Matz')

        followup = chat.ask('What year did he create Ruby?')
        expect(followup.content).to include('199')
      end
    end

    it 'claude-3-5-haiku can handle system messages with bedrock' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      chat = RubyLLM.chat(model: 'claude-3-5-haiku', provider: 'bedrock')

      # Add a system message
      chat.add_message(role: :system, content: 'You are a helpful math tutor who always shows your work.')

      response = chat.ask('What is 15 + 27?')
      expect(response.content).to include('42')
      expect(response.content).to match(/step|work|process/i) # Should show work as instructed

      # Add another system message
      chat.add_message(role: :system, content: 'Always include a fun fact about numbers in your response.')

      response = chat.ask('What is 25 * 4?')
      expect(response.content).to include('100')
      expect(response.content).to match(/step|work|process/i) # Should still show work
      expect(response.content).to match(/fact|interesting|did you know/i) # Should include a fun fact
    end
  end
end
