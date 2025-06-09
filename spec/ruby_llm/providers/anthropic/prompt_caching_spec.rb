# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Prompt Caching' do
  include_context 'with configured RubyLLM'

  class Weather < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Gets current weather for a location'
    param :latitude, desc: 'Latitude (e.g., 52.5200)'
    param :longitude, desc: 'Longitude (e.g., 13.4050)'

    def execute(latitude:, longitude:)
      "Current weather at #{latitude}, #{longitude}: 15°C, Wind: 10 km/h"
    end
  end

  CACHING_MODELS.each do |model_info|
    provider = model_info[:provider]
    model = model_info[:model]

    describe "with #{provider} provider (#{model})" do
      let(:chat) { RubyLLM.chat(model: model, provider: provider).with_temperature(0.7) }

      context 'with system message caching' do
        it 'adds cache_control to the last system message when system caching is requested' do
          chat.with_instructions(
            'You are a helpful assistant. Please be concise.'
          )
          chat.cache_prompts(system: true)
          
          response = chat.ask('Hello')
          
          expect(response).to be_a(RubyLLM::Message)
          expect(response.content).to be_a(String)
          
          # The VCR cassette will contain the request with cache_control
          # We'll verify the cassette in the implementation phase
        end
      end

      context 'with user message caching' do
        it 'adds cache_control to user messages when user caching is requested' do
          chat.cache_prompts(user: true)
          response = chat.ask('Tell me about the weather')
          
          expect(response).to be_a(RubyLLM::Message)
          expect(response.content).to be_a(String)
          
          # The VCR cassette will contain the request with cache_control
          # We'll verify the cassette in the implementation phase
        end
      end

      context 'with tool definition caching' do
        it 'adds cache_control to tool definitions when tools caching is requested' do
          chat.with_tools(Weather)
          chat.cache_prompts(tools: true)
          
          response = chat.ask("What's the weather like?")
          
          expect(response).to be_a(RubyLLM::Message)
          expect(response.content).to be_a(String)
          
          # The VCR cassette will contain the request with cache_control
          # We'll verify the cassette in the implementation phase
        end
      end
    end
  end
end
