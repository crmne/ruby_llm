# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, :live do
  include_context 'with configured RubyLLM'

  class WeatherLookup < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Looks up the current weather for a city'
    parameter :city, description: 'City name'

    def execute(city:)
      "Sunny and 22°C in #{city}"
    end
  end

  class StockPrice < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Looks up the current price of a stock ticker'
    parameter :ticker, description: 'Ticker symbol'

    def execute(ticker:)
      "#{ticker} is trading at 100"
    end
  end

  describe 'deferred tools' do
    each_model(TOOL_SEARCH_MODELS) do |provider, model|
      context "with #{provider}/#{model}" do
        let(:chat) { RubyLLM.chat(model: model, provider: provider).with_tools(WeatherLookup, StockPrice, defer: true) }

        def searched?(chat)
          chat.messages.flat_map { |message| Array(message.raw_content) }
              .any? { |item| %w[tool_search_tool_result tool_search_output].include?(item['type']) }
        end

        def called_tools(chat)
          chat.messages.select(&:tool_call?).flat_map { |message| message.tool_calls.values.map(&:name) }
        end

        it 'loads a deferred tool through tool search and calls it' do
          response = chat.ask('What is the weather in Berlin right now? Use your tools.')

          expect(response.content).to include('22')
          expect(searched?(chat)).to be(true)
          expect(called_tools(chat)).to include('weather_lookup')
        end

        it 'keeps using a loaded tool on the next turn' do
          chat.ask('What is the weather in Berlin right now? Use your tools.')

          response = chat.ask('And in Paris?')

          expect(response.content).to include('22')
          expect(called_tools(chat).count('weather_lookup')).to eq(2)
        end

        it 'loads a deferred tool while streaming' do
          chunks = []

          response = chat.ask('What is the weather in Berlin right now? Use your tools.') { |chunk| chunks << chunk }

          expect(response.content).to include('22')
          expect(searched?(chat)).to be(true)
          expect(called_tools(chat)).to include('weather_lookup')
        end
      end
    end
  end
end
