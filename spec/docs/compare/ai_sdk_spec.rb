# frozen_string_literal: true

require 'rails_helper'
require_relative 'doc_example_helpers'

RSpec.describe 'RubyLLM and the Vercel AI SDK guide', type: :task do
  include DocExampleHelpers

  include_context 'with configured RubyLLM'

  let(:doc_page) { '_compare/ai-sdk.md' }
  let(:model) { doc_model('anthropic_latest') }
  let(:answer) { "It's 21°C and sunny in Berlin." }

  it 'streams the weather agent through its tool' do
    stub_anthropic(tool_turn('weather', city: 'Berlin'), answer)

    expect { evaluate('class WeatherAgent') }.to output(answer).to_stdout

    expect(provider_requests.first).to include('model' => model, 'stream' => true)
    expect(provider_requests.first['system'].to_s).to include('You are a helpful weather assistant.')
    expect(provider_requests.first['tools'].first['input_schema']['required']).to eq(['city'])
    result = provider_requests.last['messages'].last['content'].first
    expect(result).to include('type' => 'tool_result')
    expect(result.to_s).to include("It's 21°C and sunny in Berlin")
  end

  it 'caps the loop at five model calls' do
    stub_anthropic(tool_turn('weather', city: 'Berlin'), answer)
    silently { evaluate('class WeatherAgent') }
    provider_requests.clear
    stub_anthropic(*Array.new(6) { tool_turn('weather', city: 'Berlin') })

    silently { evaluate('5.times do') }

    expect(provider_requests.size).to eq(5)
  end

  it 'stops the capped loop once the model answers' do
    stub_anthropic(tool_turn('weather', city: 'Berlin'), answer)
    silently { evaluate('class WeatherAgent') }
    provider_requests.clear
    stub_anthropic(tool_turn('weather', city: 'Berlin'), answer)

    expect { evaluate('5.times do') }.to output(answer).to_stdout
    expect(provider_requests.size).to eq(2)
  end

  it 'parses structured output into a Hash' do
    recipe = { recipe: { name: 'Lasagna', ingredients: [{ name: 'Pasta', amount: '500 g' }], steps: ['Bake'] } }
    stub_anthropic(JSON.generate(recipe))

    expect(evaluate('class Recipe')).to eq(JSON.parse(JSON.generate(recipe)))
    expect(provider_requests.first.to_s).to include('ingredients')
  end

  it 'stores the conversation as Chat records' do
    stub_anthropic(answer)

    expect(evaluate('acts_as_chat', from: 'chat = Chat.create!')).to eq(2)
    expect(Chat.last.messages.last.content).to eq(answer)
  end

  it 'runs the agent one step per job' do
    stub_const('ApplicationJob', Class.new(ActiveJob::Base))
    stub_anthropic(tool_turn('weather', city: 'Berlin'), answer)
    silently { evaluate('class WeatherAgent') }
    WeatherAgent.chat_class Chat
    evaluate('class AgentTurnJob')
    job = AgentTurnJob
    stub_anthropic(tool_turn('weather', city: 'Paris'), "It's 21°C and sunny in Paris.")
    chat = WeatherAgent.create!
    chat.ask_later('And in Paris?')

    job.perform_now(chat.id)
    3.times { job.perform_now(chat.id) unless chat.reload.complete? }

    expect(chat.reload).to be_complete
    expect(chat.messages.last.content).to eq("It's 21°C and sunny in Paris.")
  end

  it 'reports tokens and cost' do
    stub_anthropic(answer)

    total = evaluate('response.cost.total', chat: RubyLLM.chat(model:))

    expect(total).to be_positive
  end
end
