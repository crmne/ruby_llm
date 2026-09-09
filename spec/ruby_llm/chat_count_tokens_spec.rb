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
    context "with openai/#{model_for(:openai)}" do
      let(:chat) { RubyLLM.chat(model: model_for(:openai), provider: :openai) }

      it 'counts a staged message without mutating the chat' do
        count = chat.count_tokens('What is the capital of France?')

        expect(count).to be_a(Integer)
        expect(count).to be_positive
        expect(chat.messages).to be_empty
      end

      it 'counts instructions, tools and structured output' do
        chat.ask_later('What is the weather in Berlin?')
        base = chat.count_tokens
        schema = { type: 'object', properties: { weather: { type: 'string' } },
                   required: ['weather'], additionalProperties: false }

        configured = chat.with_instructions('Be terse.').with_tools(CountingWeather).with_schema(schema).count_tokens

        expect(configured).to be > base
      end

      it 'counts image attachments before generation' do
        base = chat.count_tokens('Describe this image.')
        chat.ask_later('Describe this image.', with: File.expand_path('../fixtures/ruby.png', __dir__))

        expect(chat.count_tokens).to be > base
      end
    end

    context "with anthropic/#{model_for(:anthropic)}" do
      let(:chat) { RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic) }

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

    context "with gemini/#{model_for(:gemini, :server_tools)}" do
      let(:chat) { RubyLLM.chat(model: model_for(:gemini, :server_tools), provider: :gemini) }

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

    context "with vertexai/#{model_for(:vertexai)}" do
      it 'counts a staged message' do
        chat = RubyLLM.chat(model: model_for(:vertexai), provider: :vertexai)

        expect(chat.count_tokens('What is the capital of France?')).to be_positive
      end
    end

    context 'with a provider without token counting' do
      it 'raises a clear error' do
        chat = RubyLLM.chat(model: model_for(:deepseek), provider: :deepseek)

        expect { chat.count_tokens('Hello') }
          .to raise_error(RubyLLM::Error, /doesn't support token counting/)
      end
    end
  end

  describe 'RubyLLM.count_tokens' do
    it 'counts one user message' do
      count = RubyLLM.count_tokens('What is the capital of France?', model: model_for(:anthropic))

      expect(count).to be_a(Integer)
      expect(count).to be_positive
    end
  end
end
