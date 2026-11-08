# frozen_string_literal: true

require 'spec_helper'
require 'timeout'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:requests) { [] }

  let(:refund) do
    Class.new(RubyLLM::Tool) do
      def self.name = 'IssueRefund'

      description 'Refunds an order'
      requires_approval
      define_method(:execute) { |order_id:| "Refunded #{order_id}" }
    end
  end

  let(:lookup) do
    Class.new(RubyLLM::Tool) do
      def self.name = 'IssueRefund'

      description 'Refunds an order, now without asking'
      define_method(:execute) { |order_id:| "Refunded #{order_id}" }
    end
  end

  let(:agent_class) do
    tool = refund
    Class.new(RubyLLM::Agent) { tools tool }
  end

  def done = RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)

  def refund_call(id = 'call_1')
    tool_call = RubyLLM::ToolCall.new(id:, name: 'issue_refund', arguments: { 'order_id' => '42' })
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { id => tool_call })
  end

  def stub_model(chat, *responses)
    seen = requests
    allow(chat.provider).to receive(:complete) do |messages, **|
      seen << messages.to_a
      responses.shift || done
    end
    chat
  end

  def paused(chat)
    stub_model(chat, refund_call).ask('Refund order 42')
    expect(chat.pending_questions.sole).to be_approval
    chat
  end

  def resumed(chat)
    Timeout.timeout(5) { chat.complete }
  end

  def refusal(chat)
    chat.messages.find(&:tool_result?).content
  end

  {
    'no note' => [[], '{"error":"The user denied the issue_refund tool call."}'],
    'a String note' => [['The order shipped already'], '{"error":"The order shipped already"}'],
    'a Hash' => [[{ error: 'Denied', reason: 'Wrong account' }], '{"error":"Denied","reason":"Wrong account"}']
  }.each do |described, (note, result)|
    it "refuses a call declined with #{described} once its tool is gone, and asks the model" do
      chat = paused(described_class.new(model: model_for(:openai)).with_tools(refund))
      chat.decline(chat.pending_questions.sole, *note)

      chat.with_tools(nil)
      expect(chat).not_to be_waiting
      expect(chat.pending_questions).to be_empty
      expect(resumed(chat).content).to eq('Done')

      expect(refusal(chat)).to eq(result)
      expect(requests.size).to eq(2)
    end
  end

  it 'refuses a declined call whose tool no longer asks for approval' do
    chat = paused(described_class.new(model: model_for(:openai)).with_tools(refund))
    chat.decline(chat.pending_questions.sole, 'The order shipped already')

    chat.with_tools(nil).with_tools(lookup)
    resumed(chat)

    expect(refusal(chat)).to eq('{"error":"The order shipped already"}')
    expect(requests.size).to eq(2)
  end

  it "refuses a call declined on an agent once the agent's tools leave it out" do
    agent = agent_class.new(model: model_for(:openai))
    paused(agent.chat)
    agent.decline(agent.pending_questions.sole)

    agent.with_tools(nil)
    Timeout.timeout(5) { agent.complete }

    expect(refusal(agent.chat)).to eq('{"error":"The user denied the issue_refund tool call."}')
    expect(requests.size).to eq(2)
  end

  it 'stops a resume that makes no progress instead of spinning' do
    chat = paused(described_class.new(model: model_for(:openai)).with_tools(refund))
    question = chat.pending_questions.sole
    chat.decline(question)
    allow(chat.instance_variable_get(:@tool_call_state)).to receive(:claim).and_return([])

    expect { resumed(chat) }.to raise_error(/no progress on tool calls #{question.id}/)
    expect(requests.size).to eq(1)
  end

  it 'goes on after a round that stalls once, as when another process just let its claim go' do
    chat = paused(described_class.new(model: model_for(:openai)).with_tools(refund))
    chat.decline(chat.pending_questions.sole)
    stalled = false
    state = chat.instance_variable_get(:@tool_call_state)
    allow(state).to receive(:claim).and_wrap_original do |claim, *args, **options, &leases|
      next claim.call(*args, **options, &leases) if stalled

      stalled = true
      []
    end

    expect(resumed(chat).content).to eq('Done')
    expect(refusal(chat)).to eq('{"error":"The user denied the issue_refund tool call."}')
  end

  it 'returns the waiting chat when a call that stalled once then pauses' do
    seat = Class.new(RubyLLM::Tool) do
      def self.name = 'PickSeat'

      description 'Asks for a seat'
      define_method(:execute) { "Seat #{ask('Window or aisle?')}" }
    end
    chat = described_class.new(model: model_for(:openai)).with_tools(seat)
    call = RubyLLM::ToolCall.new(id: 'call_seat', name: 'pick_seat', arguments: {})
    stub_model(chat, RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }))
    stalled = false
    state = chat.instance_variable_get(:@tool_call_state)
    allow(state).to receive(:claim).and_wrap_original do |claim, *args, **options, &leases|
      next claim.call(*args, **options, &leases) if stalled

      stalled = true
      []
    end

    Timeout.timeout(5) { chat.ask('Book a seat') }

    expect(chat).to be_waiting
    expect(chat.pending_questions.sole.message).to eq('Window or aisle?')
  end
end
