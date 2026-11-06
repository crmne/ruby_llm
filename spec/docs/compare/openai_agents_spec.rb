# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/open_telemetry'
require_relative 'doc_example_helpers'

RSpec.describe 'RubyLLM and the OpenAI Agents SDK guide', type: :task do
  include DocExampleHelpers

  include_context 'with configured RubyLLM'

  let(:doc_page) { '_compare/openai-agents.md' }
  let(:fact) { 'Sharks are older than trees.' }

  it 'answers through the agent and its tool' do
    stub_openai(tool_turn('history_fun_fact'), fact)

    expect { evaluate('class HistoryFunFact') }.to output("#{fact}\n").to_stdout

    expect(provider_requests.first['model']).to eq(doc_model('default_chat'))
    expect(provider_requests.first['tools'].first['name']).to eq('history_fun_fact')
    expect(provider_requests.last.to_s).to include(fact)
  end

  it 'streams through a block' do
    stub_openai('Why did the gem cross the road?')

    expect { evaluate('class Joker') }.to output('Why did the gem cross the road?').to_stdout
  end

  it 'remembers the conversation in an agent' do
    stub_openai('San Francisco.', 'California.')

    expect(evaluate('class Assistant').content).to eq('California.')
    expect(provider_requests.last.to_s).to include('San Francisco.')
  end

  it 'remembers the conversation across loads of a Chat record' do
    stub_openai('San Francisco.', 'California.')

    expect(evaluate('acts_as_chat', from: 'chat = Chat.create!').content).to eq('California.')
    expect(Chat.last.messages.count).to eq(4)
    expect(provider_requests.last.to_s).to include('San Francisco.')
  end

  it 'waits for approval and continues in another request' do
    stub_const('ApplicationAgent', Class.new(RubyLLM::Agent) { chat_class Chat })
    stub_openai(tool_turn('cancel_order', order_id: '42'), 'Order 42 is cancelled.')

    expect(evaluate('class CancelOrder')).to be(true)
    expect(provider_requests.size).to eq(1)

    chat = Chat.last
    evaluate('chat.approve params', params: { id: chat.id, tool_call_id: chat.pending_approvals.first.tool_call_id })

    expect(Chat.last.messages.last.content).to eq('Order 42 is cancelled.')
    expect(provider_requests.last.to_s).to include('Cancelled order 42')
  end

  it 'routes to the specialist the triage agent picks' do
    stub_openai(JSON.generate(specialist: 'history'), 'George Washington.')

    expect { evaluate('class TriageAgent') }.to output("George Washington.\n").to_stdout

    expect(provider_requests.first.to_s).to include('Route each homework question')
    expect(provider_requests.last.to_s).to include('You answer history questions')
  end

  it 'hands a stored chat to a specialist' do
    stub_openai(JSON.generate(specialist: 'history'), 'George Washington.')
    silently { evaluate('class TriageAgent') }
    provider_requests.clear
    stub_openai('Earlier answer.', 'John Adams.')
    chat = Chat.create!(model: doc_model('default_chat'))
    chat.ask('Who was the first president?')

    response = evaluate('HistoryTutor.new(chat:)', params: { id: chat.id, question: 'And the second?' })

    expect(response.content).to eq('John Adams.')
    expect(provider_requests.last.to_s).to include('You answer history questions', 'Earlier answer.')
  end

  it 'calls an agent class as a tool' do
    stub_openai(tool_turn('spanish_agent', task: 'Say hello in Spanish'), 'Hola, ¿cómo estás?', 'Hola, ¿cómo estás?')

    expect { evaluate('class Orchestrator') }.to output("Hola, ¿cómo estás?\n").to_stdout

    expect(provider_requests.first['tools'].map { |tool| tool['name'] }).to contain_exactly('spanish_agent',
                                                                                            'french_agent')
    expect(provider_requests[1].to_s).to include("You translate the user's message to Spanish")
  end

  it 'stops before the agent when the check trips' do
    stub_openai(JSON.generate(is_math_homework: true, reasoning: 'Solving for x.'))

    expect { evaluate('class MathHomeworkCheck') }.to output("Math homework guardrail tripped\n").to_stdout

    expect(provider_requests.size).to eq(1)
  end

  it 'runs the agent when the check passes' do
    stub_openai(JSON.generate(is_math_homework: false, reasoning: 'A support question.'), 'Happy to help.')

    expect { evaluate('class MathHomeworkCheck') }.to output("Happy to help.\n").to_stdout

    expect(provider_requests.last.to_s).to include('You are a customer support agent.')
  end

  context 'with OpenTelemetry' do
    include_context 'with OpenTelemetry tracing'

    it 'traces a model call once enabled' do
      stub_openai('Hello!')

      evaluate('RubyLLM::OpenTelemetry.enable')
      RubyLLM.chat.ask('Hello')

      expect(spans.map { |span| span.instrumentation_scope.name }).to include('ruby_llm')
    end
  end

  it 'moves an agent to another provider with the model name' do
    stub_anthropic('Tokyo rain falls soft')

    expect { evaluate('class HaikuAgent') }.to output("Tokyo rain falls soft\n").to_stdout

    expect(provider_requests.first['model']).to eq(doc_model('anthropic_latest'))
  end

  it 'reports tokens and cost' do
    stub_openai('It is sunny.')

    expect(evaluate('chat.cost.total')).to be_positive
  end
end
