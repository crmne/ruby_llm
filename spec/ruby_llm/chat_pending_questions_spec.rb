# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:runs) { [] }
  let(:chat) { described_class.new(model: model_for(:anthropic)) }

  let(:refund) do
    done = runs
    Class.new(RubyLLM::Tool) do
      def self.name = 'IssueRefund'

      description 'Refunds an order'
      requires_approval
      define_method(:execute) do |order_id:|
        done << order_id
        "Refunded #{order_id}"
      end
    end
  end

  let(:seat) do
    Class.new(RubyLLM::Tool) do
      def self.name = 'PickSeat'

      description 'Asks for a seat'
      define_method(:execute) { "Seat #{ask('Window or aisle?', choices: %w[window aisle])}" }
    end
  end

  def calls(*names)
    tool_calls = names.each_with_index.to_h do |name, index|
      id = "call_#{index + 1}"
      [id, RubyLLM::ToolCall.new(id:, name:, arguments: name == 'issue_refund' ? { 'order_id' => "4#{index}" } : {})]
    end
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls:)
  end

  def answer = RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)

  def results = chat.messages.select(&:tool_result?).map(&:content)

  def ask_for(*names)
    allow(chat.provider).to receive(:complete).and_return(calls(*names), answer)
    chat.with_tools(refund, seat).ask('Go')
  end

  it 'lists an approval as a question answered yes or no, before the tool runs' do
    response = ask_for('issue_refund')

    question = chat.pending_questions.sole
    expect(question).to be_approval
    expect(question).to have_attributes(id: response.tool_calls.first.id, message: nil, fields: [], url: nil,
                                        tool_call: have_attributes(name: 'issue_refund',
                                                                   arguments: { 'order_id' => '40' }))
    expect(chat).to be_awaiting_person
    expect(runs).to be_empty

    question.approve
    chat.complete

    expect(runs).to eq(['40'])
    expect(results).to eq(['Refunded 40'])
  end

  it 'sends the model a refusal for a denied approval' do
    ask_for('issue_refund')

    chat.pending_questions.sole.deny
    chat.complete

    expect(runs).to be_empty
    expect(results.sole).to include('denied')
  end

  it 'remembers an approval for the rest of the chat' do
    allow(chat.provider).to receive(:complete).and_return(calls('issue_refund'), answer, calls('issue_refund'), answer)
    chat.with_tools(refund).ask('Refund it')

    chat.pending_questions.sole.approve(remember: true)
    chat.complete
    chat.ask('And again')

    expect(chat.pending_questions).to be_empty
    expect(runs).to eq(%w[40 40])
  end

  it 'approves an approval it answers, and denies one it declines' do
    ask_for('issue_refund', 'issue_refund')
    first, second = chat.pending_questions

    chat.answer(first)
    chat.decline(second.id)
    chat.complete

    expect(runs).to eq(['40'])
    expect(results).to contain_exactly('Refunded 40', a_string_including('denied'))
  end

  it 'refuses an answer to an approval' do
    ask_for('issue_refund')

    expect { chat.pending_questions.sole.answer('yes') }.to raise_error(ArgumentError, /takes no answer/)
  end

  it 'lists approvals and questions together, in the order the model made the calls' do
    ask_for('pick_seat', 'issue_refund')

    expect(chat.pending_questions.map { |question| [question.tool_call.name, question.approval?] })
      .to eq([['pick_seat', false], ['issue_refund', true]])

    chat.pending_questions.each { |question| question.approval? ? question.approve : question.answer('aisle') }
    chat.complete

    expect(results).to eq(['Seat aisle', 'Refunded 41'])
  end

  it 'approves and denies by question as well as by tool call' do
    ask_for('issue_refund', 'issue_refund')
    first, second = chat.pending_questions

    chat.approve(first)
    chat.deny(second)
    chat.complete

    expect(runs).to eq(['40'])
  end

  it 'refuses to approve a question that is not an approval' do
    ask_for('pick_seat')

    expect { chat.approve(chat.pending_questions.sole) }.to raise_error(ArgumentError, /answer it instead/)
    expect { chat.deny(chat.pending_questions.sole) }.to raise_error(ArgumentError, /decline it instead/)
  end

  it 'changes nothing for a question already answered, or one whose call finished' do
    ask_for('pick_seat')
    question = chat.pending_questions.sole

    chat.answer(question.id, 'window')
    chat.answer(question.id, 'aisle')
    chat.complete
    chat.answer(question.id, 'aisle').decline(question)

    expect(results).to eq(['Seat window'])
  end

  it 'refuses a question id it does not know' do
    ask_for('pick_seat')

    expect { chat.answer('call_9/abc', 'window') }.to raise_error(ArgumentError, /Unknown question/)
  end

  it 'marks the question it was given as answered' do
    ask_for('pick_seat')
    question = chat.pending_questions.sole

    chat.answer(question, 'window')

    expect(question).to be_answered
  end

  it 'lists nothing once every call has a result' do
    ask_for('pick_seat')
    chat.pending_questions.sole.answer('aisle')
    chat.complete

    expect(chat.pending_questions).to eq([])
    expect(chat).not_to be_awaiting_person
  end

  it 'is delegated by agents' do
    response = ask_for('issue_refund')

    expect(Class.new(RubyLLM::Agent).new(chat:).pending_questions.map(&:id)).to eq([response.tool_calls.first.id])
  end
end
