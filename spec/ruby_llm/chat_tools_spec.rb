# frozen_string_literal: true

require 'spec_helper'
require 'dotenv/load'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  class Weather < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Gets current weather for a location'
    param :latitude, desc: 'Latitude (e.g., 52.5200)'
    param :longitude, desc: 'Longitude (e.g., 13.4050)'

    def execute(latitude:, longitude:)
      "Current weather at #{latitude}, #{longitude}: 15°C, Wind: 10 km/h"
    end
  end

  class BestLanguageToLearn < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Gets the best language to learn'

    def execute
      'Ruby'
    end
  end

  describe 'function calling' do
    [
      'claude-3-5-haiku-20241022',
      'gemini-2.0-flash',
      'gpt-4o-mini'
    ].each do |model|
      it "#{model} can use tools" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model)
                      .with_tool(Weather)

        response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)")
        expect(response.content).to include('15')
        expect(response.content).to include('10')
      end

      it "#{model} can use tools in multi-turn conversations" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model)
                      .with_tool(Weather)

        response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)")
        expect(response.content).to include('15')
        expect(response.content).to include('10')

        response = chat.ask("What's the weather in Paris? (48.8575, 2.3514)")
        expect(response.content).to include('15')
        expect(response.content).to include('10')
      end

      it "#{model} can use tools without parameters" do
        chat = RubyLLM.chat(model: model).with_tool(BestLanguageToLearn)
        response = chat.ask("What's the best language to learn?")
        expect(response.content).to include('Ruby')
      end

      it "#{model} can use tools with multi-turn streaming conversations" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model)
                      .with_tool(Weather)
        chunks = []

        response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)") do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(chunks.first).to be_a(RubyLLM::Chunk)
        expect(response.content).to include('15')
        expect(response.content).to include('10')

        response = chat.ask("What's the weather in Paris? (48.8575, 2.3514)") do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(chunks.first).to be_a(RubyLLM::Chunk)
        expect(response.content).to include('15')
        expect(response.content).to include('10')
      end
    end
  end
end
