# frozen_string_literal: true

require 'spec_helper'

class CountingWeather < RubyLLM::Tool
  description 'Gets current weather for a city'
  parameter :city, description: 'City name'

  def execute(city:)
    "It's sunny in #{city}."
  end
end

RSpec.describe RubyLLM::Chat, :live do
  describe '#count_tokens' do
    context 'with anthropic/claude-haiku-4-5' do
      let(:chat) { RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic) }

      it 'counts a staged message without mutating the chat' do
        count = chat.count_tokens('What is the capital of France?')

        expect(count).to be_a(Integer)
        expect(count).to be_positive
        expect(chat.messages).to be_empty
      end

      it 'counts the next request as configured' do
        chat.ask_later('What is the capital of France?')
        base = chat.count_tokens

        configured = chat.with_instructions('Be terse.').with_tools(CountingWeather).count_tokens

        expect(configured).to be > base
      end

      it 'counts requests with thinking enabled' do
        count = chat.with_thinking(budget: 2048).count_tokens('What is the capital of France?')

        expect(count).to be_positive
      end
    end

    context 'with gemini/gemini-3.5-flash' do
      let(:chat) { RubyLLM.chat(model: 'gemini-3.5-flash', provider: :gemini) }

      it 'counts a staged message without mutating the chat' do
        count = chat.count_tokens('What is the capital of France?')

        expect(count).to be_a(Integer)
        expect(count).to be_positive
        expect(chat.messages).to be_empty
      end

      it 'counts the next request as configured' do
        chat.ask_later('What is the capital of France?')
        base = chat.count_tokens

        configured = chat.with_instructions('Be terse.').with_tools(CountingWeather).count_tokens

        expect(configured).to be > base
      end
    end

    context 'with vertexai/gemini-2.5-flash' do
      it 'counts a staged message' do
        chat = RubyLLM.chat(model: 'gemini-2.5-flash', provider: :vertexai)

        expect(chat.count_tokens('What is the capital of France?')).to be_positive
      end
    end

    context 'with a provider without token counting' do
      it 'raises a clear error' do
        chat = RubyLLM.chat(model: 'gpt-5-nano', provider: :openai)

        expect { chat.count_tokens('Hello') }
          .to raise_error(RubyLLM::Error, /doesn't support token counting/)
      end
    end
  end

  describe 'RubyLLM.count_tokens' do
    it 'counts one user message' do
      count = RubyLLM.count_tokens('What is the capital of France?', model: 'claude-haiku-4-5')

      expect(count).to be_a(Integer)
      expect(count).to be_positive
    end
  end
end
