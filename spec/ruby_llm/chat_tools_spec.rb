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

  class LoopingAnswer < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Fetches posts from the r/RandomNames Reddit community.'

    def generate_fake_title
      "Topic #{SecureRandom.hex(10)}"
    end

    def execute
      # Fake some posts encouraging fetching the next page
      {
        posts: [
          { title: generate_fake_title, score: rand(1000) },
          { title: generate_fake_title, score: rand(1000) },
          { title: generate_fake_title, score: rand(1000) }
        ],
        next_page: "t3_abc123_#{rand(1000)}",
        message: 'More posts are available using the next_page token.'
      }
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
        skip 'Ollama models do not reliably use tools without parameters' if provider == :ollama
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
        skip 'Ollama models do not reliably use tools without parameters' if provider == :ollama
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

      it "#{model} can use tools with a configured tool completions limit" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        RubyLLM.configure do |config|
          config.max_tool_llm_calls = 5
        end

        chat = RubyLLM.chat(model: model)
                      .with_tools(LoopingAnswer, Weather)

        expect do
          chat.ask(
            'Fetch all of the posts from r/RandomNames. ' \
            'Fetch the next_page listed in the response until it responds with an empty array'
          )
        end.to raise_error(RubyLLM::ToolCallLimitReachedError)

        # Ensure it does not break the next ask.
        next_response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)")
        expect(next_response.content).to include('15')
        expect(next_response.content).to include('10')
      end

      it "#{model} can use tools with a tool completions limit using context" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        context = RubyLLM.context do |ctx|
          ctx.max_tool_llm_calls = 5
        end
        chat = RubyLLM.chat(model: model)
                      .with_context(context)
                      .with_tools(LoopingAnswer, Weather)

        expect do
          chat.ask(
            'Fetch all of the posts from r/RandomNames. ' \
            'Fetch the next_page listed in the response until it responds with an empty array'
          )
        end.to raise_error(RubyLLM::ToolCallLimitReachedError)

        # Ensure it does not break the next ask.
        next_response = chat.ask("What's the weather in Berlin? (52.5200, 13.4050)")
        expect(next_response.content).to include('15')
        expect(next_response.content).to include('10')
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
end
