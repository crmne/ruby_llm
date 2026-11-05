# frozen_string_literal: true

require 'rails_helper'
require_relative 'doc_example_helpers'

RSpec.describe 'RubyLLM and LangChain guide', type: :task do
  include DocExampleHelpers

  include_context 'with configured RubyLLM'

  let(:doc_page) { '_compare/langchain.md' }
  let(:model) { doc_model('anthropic_latest') }
  let(:sunny) { "It's always sunny in San Francisco!" }

  it 'answers through the agent and its tool' do
    stub_anthropic(tool_turn('weather', city: 'San Francisco'), sunny)

    expect { evaluate('class Assistant') }.to output("#{sunny}\n").to_stdout

    expect(provider_requests.first['system'].to_s).to include('You are a helpful assistant')
    expect(provider_requests.last['messages'].last['content'].to_s).to include(sunny)
  end

  it 'streams the agent with a block' do
    stub_anthropic(tool_turn('weather', city: 'San Francisco'), sunny, tool_turn('weather', city: 'SF'), sunny)
    silently { evaluate('class Assistant') }

    expect { evaluate('What is the weather in SF?" do |chunk|') }.to output(sunny).to_stdout
  end

  it 'returns structured output from the agent' do
    contact = { name: 'John Doe', email: 'john@example.com', phone: '(555) 123-4567' }
    stub_anthropic(JSON.generate(contact))

    expect(evaluate('class ContactInfo')).to eq(contact.transform_keys(&:to_s))
  end

  it 'remembers the conversation in a plain chat' do
    stub_anthropic('Hi Bob!', 'You are Bob!')

    expect(evaluate('chat.ask "What\'s my name?"').content).to eq('You are Bob!')
    expect(provider_requests.last['messages'].size).to eq(3)
  end

  it 'remembers the conversation across loads of a Chat record' do
    stub_anthropic('Hi Bob!', 'You are Bob!')

    expect(evaluate('acts_as_chat', from: 'chat = Chat.create!').content).to eq('You are Bob!')
    expect(provider_requests.last['messages'].size).to eq(3)
  end

  it 'waits for approval and continues in another request' do
    stub_const('ApplicationAgent', Class.new(RubyLLM::Agent) { chat_class Chat })
    stub_anthropic(tool_turn('execute_sql', query: 'DELETE FROM orders WHERE test'), 'Deleted 42 test orders.')

    expect(evaluate('class ExecuteSql')).to be(true)
    expect(provider_requests.size).to eq(1)

    evaluate('chat.pending_approvals.each', params: { id: Chat.last.id })

    expect(Chat.last.messages.last.content).to eq('Deleted 42 test orders.')
    expect(provider_requests.last['messages'][-1]['content'].to_s).to include('Deleted 42 rows')
  end

  it 'reports tokens and cost' do
    stub_anthropic('Hello!')

    expect(evaluate('response.cost.total')).to be_positive
  end
end
