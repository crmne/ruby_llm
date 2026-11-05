# frozen_string_literal: true

require 'spec_helper'
require_relative 'doc_example_helpers'

RSpec.describe 'Migrating from ruby-openai guide', type: :task do
  include DocExampleHelpers

  include_context 'with configured RubyLLM'

  let(:doc_page) { '_compare/migrate-ruby-openai.md' }
  let(:model) { doc_model('openai_latest') }

  it 'configures RubyLLM without a client object' do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('OPENAI_API_KEY').and_return('sk-doc')

    evaluate('config.openai_api_key')

    expect(RubyLLM.config.openai_api_key).to eq('sk-doc')
  end

  it 'asks a question and prints the answer' do
    stub_openai('Hello! How can I help?')

    expect { evaluate('response = chat.ask "Hello!"') }.to output("Hello! How can I help?\n").to_stdout
    expect(provider_requests.first['model']).to eq(model)
  end

  it 'continues a conversation without rebuilding the message array' do
    stub_openai('Hi!', 'Here is more.')

    evaluate('chat.ask "Tell me more."')

    expect(provider_requests.last['input'].map { |item| item['role'] }).to eq(%w[user assistant user])
  end

  it 'streams with a block' do
    stub_openai('Anna is a young woman.')

    expect { evaluate('chat.ask "Describe a character', chat: RubyLLM.chat(model:)) }
      .to output('Anna is a young woman.').to_stdout
  end

  it 'runs the function calling loop from a tool class' do
    stub_openai(tool_turn('current_weather', location: 'San Francisco, CA'), 'It is nice in San Francisco.')

    expect { evaluate('class CurrentWeather') }.to output("It is nice in San Francisco.\n").to_stdout

    result = provider_requests.last['input'].find { |item| item['type'] == 'function_call_output' }
    expect(result['output']).to include('The weather in San Francisco, CA is nice', 'fahrenheit')
    schema = provider_requests.first['tools'].first['parameters']
    expect(schema['properties']['unit']['enum']).to eq(%w[celsius fahrenheit])
    expect(schema['required']).to eq(['location'])
  end
end
