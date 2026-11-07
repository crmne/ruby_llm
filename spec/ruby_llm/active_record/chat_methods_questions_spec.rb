# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:refund) do
    Class.new(RubyLLM::Tool) do
      def self.name = 'IssueRefund'

      description 'Refunds an order'
      requires_approval
      define_method(:execute) { |order_id:| "Refunded #{order_id}" }
    end
  end

  let(:seat) do
    Class.new(RubyLLM::Tool) do
      def self.name = 'PickSeat'

      description 'Asks for a seat'
      define_method(:execute) { "Seat #{ask('Window or aisle?', choices: %w[window aisle]) || 'declined'}" }
    end
  end

  let(:passenger) do
    Class.new(RubyLLM::Tool) do
      def self.name = 'AddPassenger'

      description 'Asks who is flying'
      define_method(:execute) do
        found = ask('Who is flying?') do
          string :name
          integer :age, required: false
        end
        found.inspect
      end
    end
  end

  def call(name, arguments = {})
    RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name:, arguments:)
  end

  def done = RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)

  # Loads the chat as a job does, with its tools, and answers the model.
  def job_for(chat_id, *tools)
    Chat.find(chat_id).with_tools(*tools).tap do |job|
      allow(job.to_llm.provider).to receive(:complete).and_return(done)
    end
  end

  # Saves a round of calls and runs it until the calls wait on the person.
  def paused(*calls, tools: [refund, seat, passenger])
    chat = Chat.create!(model: model_for(:openai))
    chat.with_tools(*tools)
    chat.add_message(role: :user, content: 'Book it')
    tool_calls = calls.to_h { |call| [call.id, call] }
    chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls:))
    allow(chat.to_llm.provider).to receive(:complete).and_return(done)
    chat.complete
    chat
  end

  def result_of(tool_call)
    RubyLLM::ActiveRecord::ToolCall.find_by!(tool_call_id: tool_call.id).result&.content
  end

  # Runs +work+ in a forked process, as another job or web request would,
  # and returns its value, raising here what it raised there.
  def in_another_process(&work)
    skip 'needs fork' unless Process.respond_to?(:fork)

    reader, writer = IO.pipe
    pid = fork do
      reader.close
      outcome = begin
        [:value, work.call]
      rescue Exception => e # rubocop:disable Lint/RescueException
        [:error, "#{e.class}: #{e.message}"]
      end
      writer.write(Marshal.dump(outcome))
    ensure
      writer.close
      exit!(0)
    end
    writer.close
    kind, value = Marshal.load(reader.read) # rubocop:disable Security/MarshalLoad
    Process.wait(pid)
    raise "The other process raised #{value}" if kind == :error

    value
  end

  it 'reads approvals and questions from the database, without building the chat' do
    approval = call('issue_refund', 'order_id' => '42')
    question = call('pick_seat')
    chat = paused(question, approval)

    record = Chat.find(chat.id)
    allow(record).to receive(:to_llm).and_call_original

    questions = record.pending_questions
    expect(record).not_to have_received(:to_llm)
    expect(questions.map { |question| [question.tool_call.id, question.approval?, question.message] })
      .to eq([[question.id, false, 'Window or aisle?'], [approval.id, true, nil]])
    expect(questions.first.fields.sole.choices).to eq(%w[window aisle])
    expect(questions.last.tool_call.arguments).to eq('order_id' => '42')
  end

  it 'answers from another process, and carries the calls on in a third' do
    approval = call('issue_refund', 'order_id' => '42')
    question = call('pick_seat')
    chat = paused(question, approval)

    left = in_another_process do
      record = Chat.find(chat.id)
      record.pending_questions.each do |question|
        question.approval? ? question.approve : record.answer(question.id, 'aisle')
      end
      record.pending_questions.size
    end
    expect(left).to eq(0)

    in_another_process { job_for(chat.id, refund, seat).complete.content }

    expect(result_of(question)).to eq('Seat aisle')
    expect(result_of(approval)).to eq('Refunded 42')
    expect(Chat.find(chat.id).pending_questions).to be_empty
  end

  it 'answers a server question from another process, without connecting to the server' do
    files = Class.new(RubyLLM::MCP) do
      command RbConfig.ruby, File.expand_path('../../fixtures/mcp/server.rb', __dir__)
    end.new
    deploy = call('deploy')
    chat = Chat.create!(model: model_for(:openai)).with_mcp(files)
    chat.add_message(role: :user, content: 'Deploy')
    chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { deploy.id => deploy }))
    allow(chat.to_llm.provider).to receive(:complete).and_return(done)
    chat.complete

    question = Chat.find(chat.id).pending_questions.sole
    expect(question).to have_attributes(message: 'Which environment?', tool_call: have_attributes(name: 'deploy'))

    in_another_process { Chat.find(chat.id).answer(question.id, 'production') && nil }

    resumed = Chat.find(chat.id).with_mcp(files)
    allow(resumed.to_llm.provider).to receive(:complete).and_return(done)
    resumed.complete

    expect(result_of(deploy)).to eq('Deployed to production')
  ensure
    files&.close
  end

  it 'records an answer through the question, as the chat does' do
    question = call('pick_seat')
    chat = paused(question)

    Chat.find(chat.id).pending_questions.sole.answer('window')
    job_for(chat.id, seat).complete

    expect(result_of(question)).to eq('Seat window')
  end

  it 'declines a question, and denies an approval it declines' do
    approval = call('issue_refund', 'order_id' => '42')
    question = call('pick_seat')
    chat = paused(question, approval)

    Chat.find(chat.id).pending_questions.each(&:decline)
    job_for(chat.id, refund, seat).complete

    expect(result_of(question)).to eq('Seat declined')
    expect(result_of(approval)).to include('denied')
  end

  it 'remembers an approval approved through its question' do
    approval = call('issue_refund', 'order_id' => '42')
    chat = paused(approval)

    Chat.find(chat.id).pending_questions.sole.approve(remember: true)

    expect(RubyLLM::ActiveRecord::ToolCall.find_by!(tool_call_id: approval.id).approval).to eq('remembered')
  end

  it 'takes the parameters a form sends, keeping only the fields the question asks for' do
    asking = call('add_passenger')
    chat = paused(asking)
    question = chat.pending_questions.sole

    chat.answer(question.id, ActionController::Parameters.new(name: 'Ada', age: '36', admin: 'true'))
    job_for(chat.id, passenger).complete

    expect(result_of(asking)).to eq({ name: 'Ada', age: 36 }.inspect)
  end

  it 'changes nothing for a question answered twice, or after its call finished' do
    question = call('pick_seat')
    chat = paused(question)
    id = chat.pending_questions.sole.id

    Chat.find(chat.id).answer(id, 'window')
    Chat.find(chat.id).answer(id, 'aisle')
    job_for(chat.id, seat).complete
    Chat.find(chat.id).answer(id, 'aisle').decline(id)

    expect(result_of(question)).to eq('Seat window')
  end

  it 'marks the question it was given as answered or declined' do
    chat = paused(call('pick_seat'), call('pick_seat'))
    answered, declined = chat.pending_questions

    chat.answer(answered, 'window')
    chat.decline(declined)

    expect(answered.response).to eq('action' => 'accept', 'content' => { 'answer' => 'window' })
    expect(declined.response).to eq('action' => 'decline')
  end

  it 'settles nothing on a call that has its result, or asked nothing' do
    asked = call('pick_seat')
    approval = call('issue_refund', 'order_id' => '42')
    chat = paused(asked, approval)
    job_for(chat.id, seat, refund).tap { |job| job.answer(job.pending_questions.first.id, 'window') }.complete
    yielded = []

    [asked, approval].each { |tool_call| chat.settle_persisted_input(tool_call) { |input| yielded << input } }

    expect(yielded).to be_empty
  end

  it 'keeps a cancel when an answer changes nothing' do
    asking = call('pick_seat')
    chat = paused(asking)
    Chat.where(id: chat.id).update_all(cancelled: true)

    Chat.find(chat.id).settle_persisted_input(asking) { |input| input }

    expect(Chat.find(chat.id)).to be_cancelled
  end

  it 'refuses a question it never asked' do
    chat = paused(call('pick_seat'))

    expect { Chat.find(chat.id).answer('call_unknown/abc', 'window') }
      .to raise_error(ArgumentError, /Unknown question/)
  end

  it 'refuses an answer the question cannot take, and keeps waiting' do
    chat = paused(call('pick_seat'))
    id = chat.pending_questions.sole.id

    expect { Chat.find(chat.id).answer(id, 'middle') }.to raise_error(ArgumentError, /not one of the choices/)
    expect(Chat.find(chat.id).pending_questions.map(&:id)).to eq([id])
  end

  it 'keeps both answers when two processes answer two questions of one call at once' do
    asking = call('pick_seat')
    chat = paused(asking)
    row = RubyLLM::ActiveRecord::ToolCall.find_by!(tool_call_id: asking.id)
    questions = %w[environment region].map do |name|
      RubyLLM::Question.new(name, { 'mode' => 'form', 'message' => "Which #{name}?",
                                    'requestedSchema' => { 'properties' => { name => { 'type' => 'string' } } } })
    end
    row.update!(mcp_state: { 'requests' => questions.map(&:to_h), 'request_state' => 'state' })
    first, second = Chat.find(chat.id).pending_questions.map(&:id)

    reader, writer = IO.pipe
    start = Queue.new
    answering = Thread.new do
      start.pop
      Chat.find(chat.id).answer(first, 'staging')
    end
    pausing = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      next unless Thread.current == answering && payload[:sql].match?(/UPDATE .ruby_llm_tool_calls. SET .*mcp_state/)

      writer.puts('written')
      sleep 1
    end
    start << true
    unless reader.wait_readable(10)
      answering.join(1)
      raise 'The first answer never wrote its state'
    end
    in_another_process { Chat.find(chat.id).answer(second, 'eu') && nil }
    answering.join

    answers = row.reload.mcp_state['requests'].map { |request| request.dig('response', 'content') }
    expect(answers).to eq([{ 'environment' => 'staging' }, { 'region' => 'eu' }])
  ensure
    ActiveSupport::Notifications.unsubscribe(pausing) if pausing
    finish(answering)
  end

  it 'keeps the first decision when two processes answer and decline one approval at once' do
    refunding = call('issue_refund', 'order_id' => '42')
    chat = paused(refunding)

    reader, writer = IO.pipe
    start = Queue.new
    declining = Thread.new do
      start.pop
      Chat.find(chat.id).pending_questions.sole.decline
    end
    pausing = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      next unless Thread.current == declining && payload[:sql].match?(/UPDATE .ruby_llm_tool_calls. SET .approval/)

      writer.puts('written')
      sleep 1
    end
    start << true
    unless reader.wait_readable(10)
      declining.join(1)
      raise 'The denial was never written'
    end
    approved = in_another_process { Chat.find(chat.id).pending_questions.sole.answer.answered? }

    expect(RubyLLM::ActiveRecord::ToolCall.find_by!(tool_call_id: refunding.id).approval).to eq('denied')
    expect([declining.value.answered?, approved]).to eq([true, false])
  ensure
    ActiveSupport::Notifications.unsubscribe(pausing) if pausing
    finish(declining)
  end

  # Waits for +thread+, so the transaction it holds ends before the next
  # example, and leaves what it raised to the example's expectations.
  def finish(thread)
    thread&.join
  rescue StandardError
    nil
  end
end
