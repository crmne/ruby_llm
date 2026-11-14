# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:executions) { [] }

  let(:lookup) do
    runs = executions
    Class.new(RubyLLM::Tool) do
      def self.name = 'Lookup'

      description 'Looks something up'
      define_method(:execute) do
        runs << :lookup
        'found'
      end
    end
  end

  let(:charge) do
    runs = executions
    Class.new(RubyLLM::Tool) do
      def self.name = 'Charge'

      description 'Charges the card'
      requires_approval
      define_method(:execute) do
        runs << :charge
        'charged'
      end
    end
  end

  let(:chat) { Chat.create!(model: model_for(:openai)).tap { |chat| chat.add_message(role: :user, content: 'Go') } }

  def answer = RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)

  def asking(*names)
    tool_calls = names.each_with_index.to_h do |name, index|
      id = "call_#{SecureRandom.hex(4)}_#{index + 1}"
      [id, RubyLLM::ToolCall.new(id:, name:, arguments: {})]
    end
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls:, input_tokens: 1, output_tokens: 1)
  end

  def job(calls: 2, replies: [])
    Chat.find(chat.id).with_tools(lookup, charge).with_tool_options(calls:).tap do |job|
      allow(job.to_llm.provider).to receive(:complete) { replies.shift }
    end
  end

  def tool_calls
    RubyLLM::ActiveRecord::ToolCall.where(message_id: Chat.find(chat.id).messages.select(:id)).order(:id)
  end

  def capped_error
    { error: "This call didn't run: too many tool calls in one answer (2 at most). " \
             'Continue step by step, a few calls at a time.' }.to_json
  end

  it 'saves the error result of a capped call like any tool result' do
    job(replies: [asking('lookup', 'lookup', 'lookup'), answer]).complete

    expect(Chat.find(chat.id).messages.order(:id).map(&:role)).to eq(%w[user assistant tool tool tool assistant])
    expect(tool_calls.map { |call| call.result&.content }).to eq(['found', 'found', capped_error])
    expect(executions).to eq(%i[lookup lookup])
  end

  it 'claims only the calls within the cap' do
    claimed = []
    record = job(replies: [asking('lookup', 'lookup', 'lookup'), answer])
    allow(record).to receive(:claim_persisted_tool_calls).and_wrap_original do |original, leases, **kwargs|
      claimed.concat(leases.keys.map(&:id))
      original.call(leases, **kwargs)
    end

    record.complete

    expect(claimed).to eq(tool_calls.first(2).map(&:tool_call_id))
  end

  it 'leaves no approval row and no question for an approval-required call past the cap' do
    job(replies: [asking('lookup', 'lookup', 'charge'), answer]).complete

    expect(tool_calls.last).to have_attributes(name: 'charge', approval: nil, claimed_until: nil)
    expect(tool_calls.last.result.content).to eq(capped_error)
    expect(Chat.find(chat.id)).not_to be_waiting
    expect(Chat.find(chat.id).pending_questions).to be_empty
    expect(executions).to eq(%i[lookup lookup])
  end

  it 'saves the pending approval of a call within the cap' do
    job(replies: [asking('charge', 'lookup', 'lookup')]).complete

    expect(tool_calls.first).to have_attributes(name: 'charge', approval: 'pending')
    expect(Chat.find(chat.id).pending_questions.map(&:id)).to eq([tool_calls.first.tool_call_id])
  end

  it 'names the chat in the event' do
    events = []
    instrumenter = Class.new do
      define_method(:instrument) do |name, payload = {}, &block|
        events << payload if name == 'tool_calls_capped.ruby_llm'
        block&.call(payload)
      end
    end.new
    allow(RubyLLM.config).to receive(:instrumenter).and_return(instrumenter)

    job(replies: [asking('lookup', 'lookup', 'lookup'), answer]).complete

    expect(events.sole).to include(chat_id: chat.id, requested: 3, allowed: 2, capped: 1)
  end

  it 'takes the cap from the agent in a job that finds the chat' do
    tools = [lookup, charge]
    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      tools(*tools)
      tool_options calls: 2
    end
    record = agent_class.find(chat.id)
    replies = [asking('lookup', 'lookup', 'lookup'), answer]
    allow(record.to_llm.provider).to receive(:complete) { replies.shift }

    expect(record.complete.content).to eq('Done')
    expect(tool_calls.last.result.content).to eq(capped_error)
  end
end
