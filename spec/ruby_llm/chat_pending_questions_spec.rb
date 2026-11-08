# frozen_string_literal: true

require 'spec_helper'
require 'action_controller/metal/strong_parameters'

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
    expect(chat.waiting? && (chat.pending_questions.any? || chat.pending_tasks.any?(&:input_required?))).to be(true)
    expect(runs).to be_empty

    question.approve
    chat.complete

    expect(runs).to eq(['40'])
    expect(results).to eq(['Refunded 40'])
  end

  it 'sends the model the default refusal for a declined approval' do
    ask_for('issue_refund')

    chat.pending_questions.sole.decline
    chat.complete

    expect(runs).to be_empty
    expect(results.sole).to eq('{"error":"The user denied the issue_refund tool call."}')
  end

  it "sends the model the person's note as the result of an approval they declined" do
    ask_for('issue_refund')

    chat.decline(chat.pending_questions.sole, 'The order shipped already')
    chat.complete

    expect(runs).to be_empty
    expect(results.sole).to eq('{"error":"The order shipped already"}')
  end

  it "adds the person's note to the result of a tool whose question they declined, after ask returns nil" do
    ask_for('pick_seat')

    chat.pending_questions.sole.decline('I will choose at the gate')
    chat.complete

    expect(results.sole).to eq("Seat \n\nThe user declined: I will choose at the gate")
  end

  it 'runs a declined call that is approved after all, without the note' do
    response = ask_for('issue_refund')

    chat.decline(chat.pending_questions.sole, 'Not yet')
    chat.approve(response.tool_calls.first.id)
    chat.complete

    expect(runs).to eq(['40'])
    expect(results.sole).to eq('Refunded 40')
  end

  it 'keeps the note a copy of the chat declines with out of the original' do
    response = ask_for('issue_refund')
    id = response.tool_calls.first.id

    chat.dup.decline(id, 'Not yet')
    chat.decline(id)
    chat.complete

    expect(results.sole).to eq('{"error":"The user denied the issue_refund tool call."}')
  end

  it 'approves a call the chat has not seen yet without raising' do
    expect(chat.approve('call_later')).to eq(chat)
  end

  it 'keeps the turn ending when a tool halts on a declined question, with the note after its result' do
    halting = Class.new(RubyLLM::Tool) do
      def self.name = 'PickSeat'

      description 'Asks for a seat'
      define_method(:execute) { ask('Window or aisle?', choices: %w[window aisle]) || halt('No seat chosen.') }
    end
    allow(chat.provider).to receive(:complete).and_return(calls('pick_seat'), answer)
    chat.with_tools(halting).ask('Go')

    chat.pending_questions.sole.decline('At the gate')
    chat.complete

    expect(results.sole).to eq("No seat chosen.\n\nThe user declined: At the gate")
    expect(chat.provider).to have_received(:complete).once
  end

  it 'keeps the files a tool returns after a declined question, with the note after its text' do
    filing = Class.new(RubyLLM::Tool) do
      def self.name = 'PickSeat'

      description 'Asks for a seat'
      define_method(:execute) do
        ask('Window or aisle?', choices: %w[window aisle])
        ['Your boarding pass', RubyLLM::Attachment.new(StringIO.new('pass'), filename: 'pass.txt')]
      end
    end
    allow(chat.provider).to receive(:complete).and_return(calls('pick_seat'), answer)
    chat.with_tools(filing).ask('Go')

    chat.pending_questions.sole.decline('At the gate')
    chat.complete

    result = chat.messages.find(&:tool_result?)
    expect(result.content).to eq("Your boarding pass\n\nThe user declined: At the gate")
    expect(result.attachments.map(&:filename)).to eq(['pass.txt'])
  end

  it 'takes a blank note as no note' do
    ask_for('issue_refund')

    chat.pending_questions.sole.decline(' ')
    chat.complete

    expect(results.sole).to eq('{"error":"The user denied the issue_refund tool call."}')
  end

  it 'says no with decline alone' do
    expect([described_class, RubyLLM::Question, RubyLLM::Agent].select { |owner| owner.method_defined?(:deny) })
      .to be_empty
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

  it 'refuses an answer to an approval, and takes a blank one as none' do
    ask_for('issue_refund')
    question = chat.pending_questions.sole

    expect { question.answer('yes') }.to raise_error(ArgumentError, /takes no answer/)

    chat.answer(question.id, '')
    chat.complete

    expect(runs).to eq(['40'])
  end

  it 'keeps the first decision when two threads answer and decline one approval at once' do
    ask_for('issue_refund')
    declined, approved = Array.new(2) { chat.pending_questions.sole }
    paused = Queue.new
    resume = Queue.new
    # Holds the refusal between finding the approval pending and recording it.
    allow(chat).to receive(:refuse).and_wrap_original do |original, *args|
      paused << true
      resume.pop
      original.call(*args)
    end

    first = Thread.new { declined.decline }
    paused.pop
    second = Thread.new { approved.answer }
    second.join(0.2)
    resume << true
    [first, second].each(&:join)
    chat.complete

    expect(runs).to be_empty
    expect([declined, approved].map(&:answered?)).to eq([true, false])
  end

  it 'takes the parameters a form sends for several fields, by question id' do
    profile = Class.new(RubyLLM::Tool) do
      def self.name = 'Profile'

      description 'Asks who is flying'
      define_method(:execute) do
        ask('Who is flying?') do
          string :name
          integer :age
        end.inspect
      end
    end
    allow(chat.provider).to receive(:complete).and_return(calls('profile'), answer)
    chat.with_tools(profile).ask('Book')

    form = ActionController::Parameters.new(name: 'Ada', age: '36', admin: 'true')
    chat.answer(chat.pending_questions.sole.id, form).complete

    expect(results).to eq([{ name: 'Ada', age: 36 }.inspect])
  end

  it 'lists approvals and questions together, in the order the model made the calls' do
    ask_for('pick_seat', 'issue_refund')

    expect(chat.pending_questions.map { |question| [question.tool_call.name, question.approval?] })
      .to eq([['pick_seat', false], ['issue_refund', true]])

    chat.pending_questions.each { |question| question.approval? ? question.approve : question.answer('aisle') }
    chat.complete

    expect(results).to eq(['Seat aisle', 'Refunded 41'])
  end

  it 'approves and declines by question as well as by tool call' do
    ask_for('issue_refund', 'issue_refund', 'issue_refund')
    first, second, third = chat.pending_questions

    chat.approve(first)
    chat.decline(second)
    chat.decline(third.tool_call)
    chat.complete

    expect(runs).to eq(['40'])
  end

  it 'refuses to approve a question that is not an approval' do
    ask_for('pick_seat')

    expect { chat.approve(chat.pending_questions.sole) }.to raise_error(ArgumentError, /answer it instead/)
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

  it 'marks the question it was given as answered or declined' do
    ask_for('pick_seat', 'pick_seat')
    answered, declined = chat.pending_questions

    chat.answer(answered, 'window')
    chat.decline(declined)

    expect(answered.response).to eq('action' => 'accept', 'content' => { 'answer' => 'window' })
    expect(declined.response).to eq('action' => 'decline')
  end

  def ask_two_at_once
    deploy = Class.new(RubyLLM::Tool) do
      def self.name = 'Deploy'

      description 'Asks two things at once'
      define_method(:execute) do
        questions = %w[environment region].map do |field|
          RubyLLM::Question.new(field, { 'message' => "Which #{field}?",
                                         'requestedSchema' => { 'properties' => { field => { 'type' => 'string' } } } })
        end
        raise RubyLLM::InputRequiredError.new(name, { 'requests' => questions })
      end
    end
    allow(chat.provider).to receive(:complete).and_return(calls('deploy'), answer)
    chat.with_tools(deploy).ask('Deploy')
  end

  it 'answers one of the questions a call asks at once, and leaves the others waiting' do
    ask_two_at_once

    chat.pending_questions.first.answer('staging')

    expect(chat.pending_questions.map(&:message)).to eq(['Which region?'])
  end

  it 'keeps both answers when two threads answer the questions of one call at once' do
    ask_two_at_once
    environment, region = chat.pending_questions
    paused = Queue.new
    resume = Queue.new
    # Holds the first answer between reading the call's questions and writing them back.
    allow_any_instance_of(RubyLLM::Question).to receive(:answered_input).and_wrap_original do |original, *args| # rubocop:disable RSpec/AnyInstance
      if original.receiver.id == environment.id
        paused << true
        resume.pop
      end
      original.call(*args)
    end

    first = Thread.new { chat.answer(environment, 'staging') }
    paused.pop
    second = Thread.new { chat.answer(region, 'eu') }
    second.join(0.2)
    resume << true
    [first, second].each(&:join)

    expect(chat.pending_questions).to be_empty
  end

  it 'reads an approval in one line' do
    ask_for('issue_refund')

    expect(chat.pending_questions.sole.inspect)
      .to match(/\A#<RubyLLM::Question id: "[^"]+", approval: true, tool_call: "issue_refund">\z/)
  end

  it 'lists nothing once every call has a result' do
    ask_for('pick_seat')
    chat.pending_questions.sole.answer('aisle')
    chat.complete

    expect(chat.pending_questions).to eq([])
    expect(chat.waiting? && (chat.pending_questions.any? || chat.pending_tasks.any?(&:input_required?))).to be(false)
  end

  it 'is delegated by agents' do
    response = ask_for('issue_refund')

    expect(Class.new(RubyLLM::Agent).new(chat:).pending_questions.map(&:id)).to eq([response.tool_calls.first.id])
  end
end
