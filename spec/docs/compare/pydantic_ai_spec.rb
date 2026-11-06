# frozen_string_literal: true

require 'rails_helper'
require_relative 'doc_example_helpers'

RSpec.describe 'RubyLLM and Pydantic AI guide', type: :task do
  include DocExampleHelpers

  include_context 'with configured RubyLLM'

  let(:doc_page) { '_compare/pydantic-ai.md' }
  let(:model) { doc_model('anthropic_latest') }
  let(:advice) { { support_advice: 'Hello John, your balance is $123.45.', block_card: false, risk: 1 } }

  before do
    john = Struct.new(:name, :balance).new('John', 123.45)
    stub_const('Customer', Class.new { define_singleton_method(:find) { |_id| john } })
  end

  it 'answers for the customer through its tool and returns the schema' do
    stub_anthropic(tool_turn('customer_balance'), JSON.generate(advice))

    expect { evaluate('class CustomerBalance') }.to output(/"block_card"\s*=>\s*false/).to_stdout

    first = provider_requests.first
    expect(first['model']).to eq(model)
    expect(first['system'].to_s).to include("The customer's name is John.")
    expect(first['tools'].first['name']).to eq('customer_balance')
    expect(first.dig('output_config', 'format', 'schema', 'properties').keys)
      .to contain_exactly('support_advice', 'block_card', 'risk')
    expect(provider_requests.last['messages'].last['content'].to_s).to include('$123.45')
  end

  it 'streams with a block' do
    stub_anthropic('The capital of the UK is London.')

    expect { evaluate('What is the capital of the UK?" do |chunk|') }
      .to output('The capital of the UK is London.').to_stdout
    expect(provider_requests.first).to include('model' => model, 'stream' => true)
  end

  it 'keeps the conversation in a Chat record across loads' do
    stub_anthropic('Why did the gem cross the road?', 'It wanted a new dependency.')

    expect(evaluate('Chat.find(chat.id).ask "Explain?"', from: 'chat = Chat.create!').content)
      .to eq('It wanted a new dependency.')
    expect(provider_requests.last['messages'].size).to eq(3)
    expect(Chat.last.messages.count).to eq(4)
  end

  it 'waits for approval and continues in another request' do
    stub_const('ApplicationAgent', Class.new(RubyLLM::Agent) { chat_class Chat })
    stub_anthropic(tool_turn('issue_refund', order_id: 'R-1042', amount: '12.50'), 'Refunded 12.50 on R-1042.')

    expect(evaluate('class IssueRefund')).to be(true)
    expect(provider_requests.size).to eq(1)

    chat = Chat.last
    evaluate('chat.approve params', params: { id: chat.id, tool_call_id: chat.pending_approvals.first.tool_call_id })

    expect(Chat.last.messages.last.content).to eq('Refunded 12.50 on R-1042.')
    expect(provider_requests.last['messages'].last['content'].to_s).to include('Refunded 12.50 on order R-1042')
  end

  it 'reports tokens and cost on the response' do
    stub_anthropic(tool_turn('customer_balance'), JSON.generate(advice), JSON.generate(advice))
    silently { evaluate('class CustomerBalance') }
    provider_requests.clear
    stub_anthropic(JSON.generate(advice))

    expect(evaluate('response.cost.total', from: 'response = SupportAgent.new')).to be_positive
  end

  it 'sums spend per owner from the usage ledger' do
    stub_anthropic('Your balance is $123.45.')
    owner = Chat.create!(model: model)

    expect(evaluate('RubyLLM::ActiveRecord::Usage.where', current_user: owner)).to be_positive
  end
end
