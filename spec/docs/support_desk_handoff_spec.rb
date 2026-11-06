# frozen_string_literal: true

require 'rails_helper'
require_relative 'compare/doc_example_helpers'

RSpec.describe 'Support desk handoffs in the Agentic Workflows guide', type: :task do
  include DocExampleHelpers

  include_context 'with configured RubyLLM'

  let(:orders) { Class.new { def find_by(*) = nil }.new }
  let(:customer) { Struct.new(:name, :orders).new('Ada', orders) }
  let(:chat) { Chat.create!(model: doc_model('default_chat')) }
  let(:current_page) { {} }

  before do
    who = customer
    stub_const('SearchDocs', Class.new(RubyLLM::Tool) { description 'Searches' })
    stub_const('IssueRefund', Class.new(RubyLLM::Tool) { description 'Issues a refund' })
    allow(Chat).to receive(:find) do |id|
      Chat.find_by!(id:).tap { |record| record.define_singleton_method(:customer) { who } }
    end

    use_page '_getting_started/tools.md'
    evaluate('class LookupOrder')
    use_page '_getting_started/agents.md'
    evaluate('class TicketTriage')
    stub_openai('It shipped.')
    evaluate('agent = SupportAgent.new(customer: current_customer)', current_customer: customer)
    provider_requests.clear
    WebMock.reset!
  end

  def doc_page = current_page.fetch(:path)

  def use_page(path) = current_page[:path] = path

  def tool_names(request) = request['tools'].map { |tool| tool['name'] }

  def define_specialists
    use_page '_advanced/agentic-workflows.md'
    evaluate('class SupportRouter')
  end

  it 'routes a message to the specialist on the saved chat' do
    define_specialists
    evaluate('class SupportHandoff')
    stub_openai('{"category":"shipping","priority":"normal","summary":"Tracking."}', 'It ships tomorrow.')

    SupportHandoff.new.call(chat.id, 'Where is my parcel?')

    expect(chat.messages.reload.map(&:content)).to include('Where is my parcel?', 'It ships tomorrow.')
    expect(tool_names(provider_requests.last)).to eq(['lookup_order'])
  end

  it 'hands the conversation over when the model calls the tool' do
    define_specialists
    evaluate('class SupportDesk')
    stub_openai(tool_turn('handoff', specialist: 'shipping'), 'Shipping here: it ships tomorrow.')

    answer = SupportDesk.new.call(chat.id, 'Where is my parcel?')

    expect(answer.content).to eq('Shipping here: it ships tomorrow.')
    expect(tool_names(provider_requests.first)).to include('handoff', 'lookup_order', 'search_docs')
    expect(tool_names(provider_requests.last)).to eq(['lookup_order'])
    expect(provider_requests.last['model']).to eq(doc_model('default_chat'))
  end

  it 'lets the model correct a handoff to an unknown specialist' do
    define_specialists
    evaluate('class SupportDesk')
    stub_openai(tool_turn('handoff', specialist: 'legal'), tool_turn('handoff', specialist: 'billing'), 'Billing here.')

    answer = SupportDesk.new.call(chat.id, 'Why was I charged twice?')

    expect(answer.content).to eq('Billing here.')
    first_result = provider_requests[1]['input'].find { |item| item['type'] == 'function_call_output' }
    expect(first_result['output']).to include('Choose billing or shipping')
  end

  it 'gives up on a reply the critic never passes, after two revisions' do
    use_page '_advanced/agentic-workflows.md'
    evaluate('class PolicyCritic')
    revise = '{"verdict":"revise","feedback":"Mention store credit."}'
    stub_openai('Draft.', revise, 'Second draft.', revise, 'Third draft.', revise)

    expect(PolicyCheckedReply.new.call(customer, 'Can I return this after 40 days?')).to be_nil
    expect(provider_requests.size).to eq(6)
  end

  it 'answers without a handoff when the model does not call the tool' do
    define_specialists
    evaluate('class SupportDesk')
    stub_openai('We ship to Canada.')

    answer = SupportDesk.new.call(chat.id, 'Do you ship to Canada?')

    expect(answer.content).to eq('We ship to Canada.')
    expect(provider_requests.size).to eq(1)
  end
end
