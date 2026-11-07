# frozen_string_literal: true

require 'rails_helper'
require_relative 'compare/doc_example_helpers'

RSpec.describe 'A subagent that waits for a person in the Agents guide', type: :task do
  include DocExampleHelpers

  include_context 'with configured RubyLLM'

  let(:refunds) { [] }
  let(:chat) { SupportAgent.create! }

  before do
    refunded = refunds
    stub_const('ApplicationAgent', Class.new(RubyLLM::Agent) { chat_class Chat })
    ApplicationAgent.model doc_model('default_chat')
    stub_const('IssueRefund', Class.new(RubyLLM::Tool) do
      description 'Refunds an order'
      parameter :order, description: 'The order number'
      requires_approval

      define_method(:execute) do |order:|
        refunded << order
        "Refunded #{order}"
      end
    end)
    stub_const('BillingAgent', Class.new(ApplicationAgent) { tools IssueRefund })
    evaluate('class AskBilling < RubyLLM::Tool')
    stub_const('SupportAgent', Class.new(ApplicationAgent) { tools AskBilling })
  end

  def doc_page = '_getting_started/agents.md'

  def tool_outputs(request)
    request['input'].select { |item| item['type'] == 'function_call_output' }.map { |item| item['output'] }
  end

  it 'answers at once when the billing agent needs nobody' do
    stub_openai(tool_turn('ask_billing', request: 'What does the customer owe?'), 'Nothing is owed.',
                'You owe nothing.')

    reply = SupportAgent.find(chat.id).ask('What do I owe?')

    expect(reply.content).to eq('You owe nothing.')
    expect(tool_outputs(provider_requests.last)).to eq(['Nothing is owed.'])
    billing = Chat.where(Chat.arel_table[:id].gt(chat.id)).sole
    expect(billing.messages.map(&:content)).to include('What does the customer owe?', 'Nothing is owed.')
  end

  it 'pauses on a task holding the billing chat, and carries both on once a person approves' do
    stub_openai(tool_turn('ask_billing', request: 'Refund order R-1042'), tool_turn('issue_refund', order: 'R-1042'),
                'Refunded R-1042.', 'Your refund is on its way.')

    SupportAgent.find(chat.id).ask('Please refund order R-1042')

    waiting = SupportAgent.find(chat.id)
    expect(waiting).to be_waiting
    expect(waiting.pending_tasks.sole).to be_input_required
    expect(refunds).to be_empty

    evaluate('task = chat.pending_tasks', chat: SupportAgent.find(chat.id))

    expect(refunds).to eq(['R-1042'])
    expect(tool_outputs(provider_requests.last)).to eq(['Refunded R-1042.'])
    expect(chat.messages.reload.last.content).to eq('Your refund is on its way.')
    expect(SupportAgent.find(chat.id)).not_to be_waiting
  end
end
