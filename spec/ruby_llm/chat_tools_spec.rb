# frozen_string_literal: true

require 'spec_helper'

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

  class BrokenTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Gets current weather'

    def execute
      raise 'This tool is broken'
    end
  end

  describe 'function calling' do
    CHAT_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can use tools" do # rubocop:disable RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(Weather)

        response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)")
        expect(response.content).to include('15')
        expect(response.content).to include('10')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can use tools in multi-turn conversations" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(Weather)

        response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)")
        expect(response.content).to include('15')
        expect(response.content).to include('10')

        response = chat.ask("What's the weather in Paris? (48.8575, 2.3514)")
        expect(response.content).to include('15')
        expect(response.content).to include('10')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can use tools without parameters" do
        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(BestLanguageToLearn)
        response = chat.ask("What's the best language to learn?")
        expect(response.content).to include('Ruby')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can use tools without parameters in multi-turn streaming conversations" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
                      .with_tool(BestLanguageToLearn)
                      .with_instructions('You must use tools whenever possible.')
        chunks = []

        response = chat.ask("What's the best language to learn?") do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(chunks.first).to be_a(RubyLLM::Chunk)
        expect(response.content).to include('Ruby')

        response = chat.ask("Tell me again: what's the best language to learn?") do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(chunks.first).to be_a(RubyLLM::Chunk)
        expect(response.content).to include('Ruby')
      end
    end

    CHAT_MODELS.each do |model_info| # rubocop:disable Style/CombinableLoops
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can use tools with multi-turn streaming conversations" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
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

  describe 'error handling' do
    it 'raises an error when tool execution fails' do # rubocop:disable RSpec/MultipleExpectations
      chat = RubyLLM.chat.with_tool(BrokenTool)

      expect { chat.ask('What is the weather?') }.to raise_error(RuntimeError) do |error|
        expect(error.message).to include('This tool is broken')
      end
    end
  end

  describe 'tool management' do
    let(:chat) { RubyLLM.chat }
    let(:weather_tool) { Weather.new }
    let(:best_language_tool) { BestLanguageToLearn.new }

    before do
      chat.with_tool(Weather)
      chat.with_tool(BestLanguageToLearn)
    end

    describe '#without_tool' do
      it 'removes a tool by class' do
        expect(chat.tools.keys).to include(:weather, :best_language_to_learn)
        
        chat.without_tool(Weather)
        
        expect(chat.tools.keys).not_to include(:weather)
        expect(chat.tools.keys).to include(:best_language_to_learn)
      end

      it 'removes a tool by instance' do
        expect(chat.tools.keys).to include(:weather, :best_language_to_learn)
        
        chat.without_tool(weather_tool)
        
        expect(chat.tools.keys).not_to include(:weather)
        expect(chat.tools.keys).to include(:best_language_to_learn)
      end

      it 'returns self for method chaining' do
        expect(chat.without_tool(weather_tool)).to be(chat)
      end
    end

    describe '#without_tools' do
      it 'removes multiple tools by class' do
        expect(chat.tools.keys).to include(:weather, :best_language_to_learn)
        
        chat.without_tools(Weather, BestLanguageToLearn)
        
        expect(chat.tools).to be_empty
      end

      it 'removes multiple tools by instance' do
        expect(chat.tools.keys).to include(:weather, :best_language_to_learn)
        
        chat.without_tools(weather_tool, best_language_tool)
        
        expect(chat.tools).to be_empty
      end

      it 'returns self for method chaining' do
        expect(chat.without_tools(weather_tool, best_language_tool)).to be(chat)
      end
    end

    describe '#clear_tools' do
      it 'removes all tools' do
        expect(chat.tools).not_to be_empty
        
        chat.clear_tools
        
        expect(chat.tools).to be_empty
      end

      it 'returns self for method chaining' do
        expect(chat.clear_tools).to be(chat)
      end
    end
  end
end
