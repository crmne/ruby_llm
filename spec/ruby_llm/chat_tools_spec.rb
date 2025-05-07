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

  class AddressBook < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Manages address book entries'

    param :contact,
          type: 'object',
          description: 'Contact information',
          properties: {
            name: {
              type: 'string',
              description: 'Full name'
            },
            address: {
              type: 'object',
              description: 'Address details',
              properties: {
                street: {
                  type: 'string',
                  description: 'Street address'
                },
                city: {
                  type: 'string',
                  description: 'City name'
                },
                zip: {
                  type: 'string',
                  description: 'ZIP/Postal code'
                }
              }
            }
          }

    def execute(contact:)
      address = contact['address']
      "Completed contact: #{contact['name']} at #{address['street']}, " \
        "#{address['city']} #{address['zip']}"
    end
  end

  class StateManager < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Manages US states information'

    param :states,
          type: 'array',
          description: 'List of states',
          items: {
            type: 'object',
            properties: {
              name: {
                type: 'string',
                description: 'The state name'
              },
              capital: {
                type: 'string',
                description: 'The capital city'
              },
              population: {
                type: 'number',
                description: 'Population count'
              }
            }
          }

    def execute(states:)
      return 'No states provided' if states.empty?

      states.map { |s| "#{s['name']}: Capital is #{s['capital']} (pop: #{s['population']})" }.join("\n")
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
    end
  end

  describe 'nested parameters' do
    chat_models.each do |model|
      provider = RubyLLM::Models.provider_for(model).slug

      context "with #{provider}/#{model}" do
        let(:chat) { RubyLLM.chat(model: model).with_tool(AddressBook) }

        it 'handles nested object parameters', :aggregate_failures do
          prompt = 'Add John Doe to the address book at 123 Main St, Springfield 12345'
          response = chat.ask(prompt)

          expect(response.content).to include('John Doe', '123 Main St',
                                              'Springfield', '12345')
        end
      end
    end
  end

  describe 'array parameters' do
    chat_models.each do |model|
      provider = RubyLLM::Models.provider_for(model).slug

      context "with #{provider}/#{model}" do
        let(:chat) { RubyLLM.chat(model: model).with_tool(StateManager) }
        let(:prompt) do
          'Add information about California (capital: Sacramento, ' \
            'pop: 39538223) and Texas (capital: Austin, pop: 29145505). ' \
            'Make sure to return all the information in the final output. '
        end

        it 'handles array parameters with object items', :aggregate_failures do
          response = chat.ask(prompt)

          expect(response.content).to include('Sacramento', 'Austin')
          expect(response.content).to match(/39538223|39,538,223/).and(match(/29145505|29,145,505/))
        end
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
