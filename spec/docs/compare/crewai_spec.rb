# frozen_string_literal: true

require 'rails_helper'
require_relative 'doc_example_helpers'

RSpec.describe 'RubyLLM and CrewAI guide', type: :task do
  include DocExampleHelpers

  include_context 'with configured RubyLLM'

  let(:doc_page) { '_compare/crewai.md' }
  let(:model) { doc_model('anthropic_latest') }

  before { stub_const('Article', Class.new) }

  it 'passes the research to the writer' do
    stub_anthropic('Qubits got steadier.', 'An article about qubits.')

    expect { evaluate('class Article') }.to output("An article about qubits.\n").to_stdout

    expect(provider_requests.first['system'].to_s).to include('meticulous researcher')
    expect(provider_requests.first['messages'].to_s).to include('quantum computing')
    expect(provider_requests.last['system'].to_s).to include('skilled content writer')
    expect(provider_requests.last['messages'].to_s).to include('Qubits got steadier.')
  end

  it 'lets the manager delegate to its team' do
    stub_anthropic(tool_turn('researcher', task: 'Research quantum computing'), 'Qubits got steadier.',
                   tool_turn('writer', task: 'Write from: Qubits got steadier.'), 'An article about qubits.',
                   'Here is your article.')

    expect { evaluate('class Manager') }.to output("Here is your article.\n").to_stdout

    expect(provider_requests.first['system'].to_s).to include('Delegate the work')
    tools = provider_requests.first['tools']
    expect(tools.map { |tool| tool['name'] }).to contain_exactly('researcher', 'writer')
    expect(tools.first['description']).to include('Researches a topic')
    expect(provider_requests[1]['system'].to_s).to include('data analyst')
    expect(provider_requests[1]['messages'].to_s).not_to include('800-word')
    expect(provider_requests.last['messages'].to_s).to include('An article about qubits.')
  end

  it 'runs the two flow steps as plain Ruby' do
    stub_const('CityFact', Class.new)
    stub_anthropic('Lisbon', 'Lisbon has a very old bookstore.')

    expect { evaluate('class CityFact') }.to output("Lisbon has a very old bookstore.\n").to_stdout

    expect(provider_requests.first['model']).to eq(model)
    expect(provider_requests.last['messages'].to_s).to include('fun fact about Lisbon')
  end

  it 'routes with a case on the triage answer' do
    stub_const('SupportRouter', Class.new)
    stub_anthropic(JSON.generate(category: 'billing'), 'Let me check that charge.')

    expect(evaluate('class SupportRouter')).to eq('Let me check that charge.')

    expect(provider_requests.first['model']).to eq(doc_model('anthropic_haiku'))
    expect(provider_requests.last['system'].to_s).to include('invoices')
  end

  it 'takes the other branch for a shipping message' do
    stub_const('SupportRouter', Class.new)
    stub_anthropic(JSON.generate(category: 'shipping'), 'It arrives tomorrow.')

    expect(evaluate('class SupportRouter')).to eq('It arrives tomorrow.')

    expect(provider_requests.last['system'].to_s).to include('tracking')
  end

  it 'runs the agent one step per job' do
    stub_const('ApplicationJob', Class.new(ActiveJob::Base))
    stub_const('ResearchTurnJob', Class.new(ApplicationJob))
    stub_anthropic('Qubits got steadier.', 'An article about qubits.', 'Qubits got steadier still.')
    silently { evaluate('class Article') }
    Researcher.chat_class Chat
    evaluate('class ResearchTurnJob')
    chat = Researcher.create!
    chat.ask_later('And this week?')

    ResearchTurnJob.perform_now(chat.id)
    2.times { ResearchTurnJob.perform_now(chat.id) unless chat.reload.complete? }

    expect(chat.reload).to be_complete
    expect(chat.messages.last.content).to eq('Qubits got steadier still.')
  end

  it 'waits for approval and continues in another request' do
    stub_const('ApplicationAgent', Class.new(RubyLLM::Agent) { chat_class Chat })
    stub_anthropic(tool_turn('publish', title: 'Quantum computing'), 'Your post is live.')

    expect(evaluate('class Publish')).to be(true)
    expect(provider_requests.size).to eq(1)

    chat = Chat.last
    evaluate('chat.approve params', params: { id: chat.id, tool_call_id: chat.pending_approvals.first.tool_call_id })

    expect(Chat.last.messages.last.content).to eq('Your post is live.')
    expect(provider_requests.last['messages'][-1]['content'].to_s).to include('Published Quantum computing')
  end

  it 'returns structured output from the agent' do
    blog = { title: 'Qubits', content: 'They got steadier.' }
    stub_anthropic(JSON.generate(blog))

    expect(evaluate('class Blog')).to eq(blog.transform_keys(&:to_s))
    expect(provider_requests.first.to_s).to include('title')
  end

  it 'reports tokens and cost' do
    stub_anthropic('Hello!')

    expect(evaluate('response.cost.total')).to be_positive
  end

  it 'totals a workflow in the usage ledger' do
    stub_anthropic('Qubits got steadier.', 'An article about qubits.', 'Qubits got steadier.', 'An article.')
    silently { evaluate('class Article') }

    expect(evaluate('RubyLLM.workflow "Article"')).to be_positive
    expect(RubyLLM::ActiveRecord::Usage.where(workflow_id: 'article-42').count).to eq(2)
  end
end
