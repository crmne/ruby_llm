# frozen_string_literal: true

require 'spec_helper'
require_relative 'compare/doc_example_helpers'

RSpec.describe 'Support desk examples in the Start Here guides', type: :task do
  include DocExampleHelpers

  include_context 'with configured RubyLLM'

  let(:order) { Struct.new(:number, :status, :shipped_on).new('R-1042', 'shipped', Date.new(2026, 11, 2)) }
  let(:orders) do
    known = order
    Class.new do
      define_method(:find_by) { |number:| known if number == known.number }
    end.new
  end
  let(:customer) { Struct.new(:name, :orders, :premium?).new('Ada', orders, false) }
  let(:article) { Struct.new(:title, :url, :body).new('Returns', 'https://help.example/returns', 'Free for 30 days.') }
  let(:current_page) { {} }

  before do
    found = [article]
    stub_const('Article', Class.new { define_singleton_method(:search) { |_query| found } })
  end

  def define_tools
    use_page '_getting_started/tools.md'
    evaluate('class SearchDocs')
    evaluate('class LookupOrder')
  end

  def doc_page = current_page.fetch(:path)

  def use_page(path) = current_page[:path] = path

  def tool_output(request)
    request['input'].find { |item| item['type'] == 'function_call_output' }['output']
  end

  it 'searches the help center with SearchDocs' do
    define_tools
    stub_openai(tool_turn('search_docs', query: 'return a jacket'), 'Start a return from Orders.')

    expect do
      evaluate('chat = RubyLLM.chat.with_tools(SearchDocs)')
    end.to output("Start a return from Orders.\n").to_stdout
    expect(JSON.parse(tool_output(provider_requests.last)).first['url']).to eq('https://help.example/returns')
  end

  it "scopes LookupOrder to the current customer's orders" do
    define_tools
    stub_openai(tool_turn('lookup_order', number: 'R-1042'), 'It shipped.',
                tool_turn('lookup_order', number: 'R-9999'), 'Not found.')

    evaluate('chat = RubyLLM.chat.with_tools(LookupOrder.new(current_customer)', current_customer: customer)

    expect(JSON.parse(tool_output(provider_requests[1]))).to include('status' => 'shipped',
                                                                     'shipped_on' => '2026-11-02')

    chat = RubyLLM.chat.with_tools(LookupOrder.new(customer))
    chat.ask 'Where is R-9999?'
    expect(tool_output(provider_requests.last)).to include('No order R-9999 on this account')
  end

  it 'builds the agent tools from the customer input' do
    define_tools
    use_page '_getting_started/agents.md'
    stub_openai(tool_turn('lookup_order', number: 'R-1042'), 'Order R-1042 shipped.')

    evaluate('agent = SupportAgent.new(customer: current_customer)', current_customer: customer)

    expect(provider_requests.first['instructions'].to_s + provider_requests.first['input'].to_s).to include('Ada')
    tool_names = provider_requests.first['tools'].map { |tool| tool['name'] }
    expect(tool_names).to contain_exactly('lookup_order', 'search_docs')
    expect(tool_output(provider_requests.last)).to include('shipped')
  end

  it 'triages an email into the fields of a ticket' do
    use_page '_getting_started/agents.md'
    stub_openai('{"category":"shipping","priority":"urgent","summary":"Late order."}')
    stub_const('ApplicationJob', Class.new)
    ticket = Struct.new(:body, :attributes) do
      def update!(values) = self.attributes = values
    end.new('Where is my order?', nil)

    evaluate('class TicketTriage')
    evaluate('class TriageTicketJob')
    TriageTicketJob.new.perform(ticket)

    expect(ticket.attributes).to eq('category' => 'shipping', 'priority' => 'urgent', 'summary' => 'Late order.')
    expect(provider_requests.first['model']).to eq(doc_model('openai_mini'))
    expect(provider_requests.first.dig('text', 'format', 'schema', 'properties', 'category', 'enum'))
      .to eq(%w[billing shipping returns other])
  end

  it 'routes a triaged message to the specialist agent' do
    define_tools
    use_page '_getting_started/agents.md'
    evaluate('class TicketTriage')
    stub_const('SupportAgent', Class.new(RubyLLM::Agent))
    stub_const('IssueRefund', Class.new(RubyLLM::Tool) { description 'Issues a refund' })
    use_page '_advanced/agentic-workflows.md'
    evaluate('class SupportRouter')

    stub_openai('{"category":"shipping","priority":"normal","summary":"Tracking."}', 'It ships tomorrow.')
    reply = SupportRouter.new.call(customer, 'Where is my parcel?')

    expect(reply.content).to eq('It ships tomorrow.')
    expect(provider_requests.last['model']).to eq(doc_model('openai_mini'))
    expect(provider_requests.last['tools'].map { |tool| tool['name'] }).to eq(['lookup_order'])
  end
end
