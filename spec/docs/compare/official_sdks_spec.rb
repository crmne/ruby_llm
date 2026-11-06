# frozen_string_literal: true

require 'rails_helper'
require_relative 'doc_example_helpers'

RSpec.describe 'RubyLLM and the Official SDKs guide', type: :task do
  include DocExampleHelpers

  include_context 'with configured RubyLLM'

  let(:doc_page) { '_compare/official-sdks.md' }
  let(:anthropic_model) { doc_model('anthropic_opus') }
  let(:openai_model) { doc_model('openai_latest') }

  it 'sends the same call to two providers' do
    stub_anthropic('Hello!')
    stub_openai('Hello!')

    expect(evaluate('RubyLLM.chat(model: "claude').content).to eq('Hello!')
    expect(provider_requests.map { |request| request['model'] }).to eq([anthropic_model, openai_model])
  end

  it 'streams with a block' do
    stub_anthropic('Hello there!')

    expect { evaluate('Say hello there!" do |chunk|') }.to output('Hello there!').to_stdout
  end

  it 'runs the calculator through the loop' do
    stub_anthropic(tool_turn('calculator', lhs: 15, rhs: 7, operator: '*'), '15 * 7 is 105.')

    expect(evaluate('class Calculator < RubyLLM::Tool').content).to eq('15 * 7 is 105.')

    schema = provider_requests.first['tools'].first['input_schema']
    expect(schema['properties']['operator']['enum']).to eq(%w[+ - * /])
    result = provider_requests.last['messages'].last['content'].first
    expect(result.to_s).to include('105')
  end

  it 'extracts the calendar event into a Hash' do
    event = { name: 'Science fair', date: 'Friday',
              participants: [{ first_name: 'Alice', last_name: 'Shah', status: 'confirmed' }] }
    stub_openai(JSON.generate(event))

    participants = evaluate('class CalendarEvent < Schematist::Schema')

    expect(participants.first['first_name']).to eq('Alice')
    expect(provider_requests.first['instructions'].to_s + provider_requests.first['input'].to_s)
      .to include('Extract the event information.')
    expect(provider_requests.first.dig('text', 'format', 'schema', 'properties')).to include('participants')
  end

  it 'stores the chat and its cost' do
    stub_anthropic('Hello!')

    expect(evaluate('acts_as_chat', from: 'chat = Chat.create!')).to be_positive
    expect(Chat.last.messages.count).to eq(2)
  end

  it 'passes a provider option through to the request' do
    stub_openai('Here is the summary.')

    evaluate('with_provider_options service_tier')

    expect(provider_requests.first['service_tier']).to eq('flex')
  end
end
