# frozen_string_literal: true

require 'rails_helper'
require 'active_support/testing/time_helpers'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'
  include ActiveSupport::Testing::TimeHelpers

  let(:lease) { 2 }
  let(:call_id) { "call_#{SecureRandom.hex(4)}" }
  let(:executions) { [] }
  let(:requests) { [] }
  let(:call_ids) { Array.new(2) { "call_#{SecureRandom.hex(4)}" } }

  before do
    stub_const('RubyLLM::ActiveRecord::RunClaims::CLAIM_LEASE', lease)
    stub_const('RubyLLM::ActiveRecord::RunClaims::CLAIM_RENEWAL', 0.1)
  end

  def lookup_tool(&during)
    runs = executions
    Class.new(RubyLLM::Tool) do
      define_method(:name) { 'lookup' }
      define_method(:execute) do
        runs << :lookup
        during&.call
        'found'
      end
    end
  end

  def job_for(chat, &during_request)
    Chat.find(chat.id).with_tools(lookup_tool).tap do |job|
      allow(job.to_llm.provider).to receive(:complete) do
        requests << job
        during_request&.call
        RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)
      end
    end
  end

  def question_chat
    Chat.create!(model: model_for(:openai)).tap { |chat| chat.add_message(role: :user, content: 'Hello') }
  end

  def tool_call_chat
    question_chat.tap do |chat|
      tool_calls = { call_id => RubyLLM::ToolCall.new(id: call_id, name: 'lookup', arguments: {}) }
      chat.add_message(role: :assistant, content: '', tool_calls:)
    end
  end

  def tool_call_record
    RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call_id)
  end

  # A chat whose last reply asks for two calls in one round.
  def round_chat
    question_chat.tap do |chat|
      tool_calls = call_ids.to_h { |id| [id, RubyLLM::ToolCall.new(id:, name: 'lookup', arguments: {})] }
      chat.add_message(role: :assistant, content: '', tool_calls:)
    end
  end

  def roles(chat)
    chat.messages_association.reload.pluck(:role)
  end

  def heartbeats
    Thread.list.select { |thread| thread.alive? && thread.name == 'ruby_llm claim heartbeat' }
  end

  def busy_process(&work)
    skip 'needs fork' unless Process.respond_to?(:fork)

    reader, writer = IO.pipe
    pid = fork do
      reader.close
      work.call(-> { writer.puts('busy') })
    ensure
      exit!(0)
    end
    writer.close
    reader.gets
    pid
  end

  def kill(pid)
    Process.kill(:KILL, pid)
    Process.wait(pid)
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # Whether the block turns true within +seconds+, so a check doesn't fail
  # on a heartbeat that runs late.
  def within?(seconds)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    loop do
      return true if yield
      return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  end

  def claimed?(tool_call_id)
    RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id:).running?
  end

  def seconds_until_free(since, &running)
    loop do
      waited = Process.clock_gettime(Process::CLOCK_MONOTONIC) - since
      return waited unless running.call && waited < lease * 3

      sleep 0.05
    end
  end

  it 'takes over the chat of a process that died while its model was silent, within a lease' do
    chat = question_chat
    pid = busy_process do |busy|
      Chat.find(chat.id).tap do |job|
        allow(job.to_llm.provider).to receive(:complete) do
          busy.call
          sleep
        end
      end.complete
    end
    sleep lease * 1.5

    expect(Chat.find(chat.id)).to be_running

    killed_at = kill(pid)

    expect(seconds_until_free(killed_at) { Chat.find(chat.id).running? }).to be < lease + 0.5

    resumed = job_for(chat)
    resumed.complete

    expect(requests).to eq([resumed])
    expect(roles(chat)).to eq(%w[user assistant])
  end

  it 'takes over the tool call of a process that died while running it, within a lease' do
    chat = tool_call_chat
    pid = busy_process do |busy|
      Chat.find(chat.id).with_tools(lookup_tool do
        busy.call
        sleep
      end).complete
    end
    sleep lease * 1.5

    expect(Chat.find(chat.id)).to be_running
    expect(tool_call_record).to be_running

    killed_at = kill(pid)

    expect(seconds_until_free(killed_at) { Chat.find(chat.id).running? || tool_call_record.running? })
      .to be < lease + 0.5

    job_for(chat).complete

    expect(executions).to eq([:lookup])
    expect(roles(chat)).to eq(%w[user assistant tool assistant])
  end

  it 'keeps its claim while its model is silent for longer than the lease' do
    chat = question_chat
    second_job = job_for(chat)
    overlap = {}
    job = job_for(chat) do
      sleep lease * 1.5
      overlap[:running] = second_job.running?
      overlap[:response] = second_job.complete
    end

    job.complete

    expect(overlap[:running]).to be(true)
    expect(requests).to eq([job])
    expect(roles(chat)).to eq(%w[user assistant])
  end

  it 'keeps the claim on a tool call that runs for longer than the lease' do
    chat = tool_call_chat
    running = []
    job = Chat.find(chat.id).with_tools(lookup_tool do
      sleep lease * 1.5
      running << tool_call_record.running?
    end)
    allow(job.to_llm.provider).to receive(:complete)
      .and_return(RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1))

    job.complete

    expect(running).to eq([true])
    expect(tool_call_record).not_to be_running
  end

  context 'when a round of calls runs longer than the run time, though each call fits it' do
    before { allow(RubyLLM.config).to receive(:max_run_time).and_return(4) }

    # Each call takes two of the four seconds and checks its claim as it
    # finishes, so the second checks four seconds into the round, when a
    # deadline counted from the round's start has passed. Deadlines are
    # whole seconds, so a call keeps at least three of its four.
    def slow_lookup(claimed, alone:)
      Class.new(RubyLLM::Tool) do
        exclusive if alone
        define_method(:name) { 'lookup' }
        define_method(:execute) do |tool_call:|
          sleep 2
          claimed << RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: tool_call.id).running?
          'found'
        end
      end
    end

    [nil, :threads, :fibers].each do |concurrency|
      it "keeps each call claimed for its own run time#{", one at a time with #{concurrency}" if concurrency}" do
        chat = round_chat
        claimed = []
        job = Chat.find(chat.id).with_tools(slow_lookup(claimed, alone: concurrency))
        job.with_tool_options(concurrency:) if concurrency
        allow(job.to_llm.provider).to receive(:complete)
          .and_return(RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1))

        job.complete

        expect(claimed).to eq([true, true])
        expect(roles(chat)).to eq(%w[user assistant tool tool assistant])
      end
    end

    it 'keeps a waiting call claimed while a callback after the call before it runs long' do
      chat = round_chat
      claimed = []
      waiting = []
      job = Chat.find(chat.id).with_tools(slow_lookup(claimed, alone: false))
      job.after_message do |message|
        next unless message.role == :tool && waiting.empty?

        # Four and a half seconds into the round, past the waiting call's
        # own deadline, its claim still holds, however late the heartbeat.
        sleep 2.5
        waiting << within?(3) { claimed?(call_ids.last) }
      end
      allow(job.to_llm.provider).to receive(:complete)
        .and_return(RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1))

      job.complete

      expect(waiting).to eq([true])
      expect(claimed).to eq([true, true])
    end

    # Another process takes something over between the two calls, as it
    # could once a claim lapsed; the second call must not run here too.
    {
      'the waiting call' => lambda { |_chat, waiting, taken|
        RubyLLM::ActiveRecord::ToolCall.where(tool_call_id: waiting).update_all(claimed_until: taken)
      },
      'the waiting call, which the heartbeat finds first' => lambda { |_chat, waiting, taken|
        RubyLLM::ActiveRecord::ToolCall.where(tool_call_id: waiting).update_all(claimed_until: taken)
        sleep 1.5
      },
      'the chat' => lambda { |chat, _waiting, taken|
        Chat.where(id: chat.id).update_all(claim_token: 'elsewhere', claimed_until: taken)
      }
    }.each do |what, take_over|
      it "does not start a call once another process took over #{what}" do
        chat = round_chat
        taken = 10.minutes.from_now.change(usec: 0)
        job = Chat.find(chat.id).with_tools(lookup_tool)
        job.after_message do |message|
          take_over.call(chat, call_ids.last, taken) if message.role == :tool
        end
        allow(job.to_llm.provider).to receive(:complete)
          .and_return(RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1))

        job.complete

        expect(executions).to eq([:lookup])
        expect(roles(chat)).to eq(%w[user assistant tool])
      end
    end
  end

  it 'lets a waiting call go once another process takes the chat over, and keeps the running one' do
    chat = round_chat
    first, waiting = call_ids
    released = []
    take_over = lambda do
      Chat.where(id: chat.id).update_all(claim_token: 'elsewhere', claimed_until: 10.minutes.from_now)
      released << within?(lease * 3) { !claimed?(waiting) } << claimed?(first)
    end
    tool = Class.new(RubyLLM::Tool) do
      define_method(:name) { 'lookup' }
      define_method(:execute) do |tool_call:|
        take_over.call if tool_call.id == first
        'found'
      end
    end
    job = Chat.find(chat.id).with_tools(tool)
    allow(job.to_llm.provider).to receive(:complete)
      .and_return(RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1))

    job.complete

    expect(released).to eq([true, true])
    expect(roles(chat)).to eq(%w[user assistant])
  end

  it 'claims a waiting call with its round, before any renewal' do
    stub_const('RubyLLM::ActiveRecord::RunClaims::CLAIM_LEASE', 60)
    stub_const('RubyLLM::ActiveRecord::RunClaims::CLAIM_RENEWAL', 30)
    chat = round_chat
    first, waiting = call_ids
    claimed = []
    check = -> { claimed << claimed?(waiting) }
    tool = Class.new(RubyLLM::Tool) do
      define_method(:name) { 'lookup' }
      define_method(:execute) do |tool_call:|
        check.call if tool_call.id == first
        'found'
      end
    end
    job = Chat.find(chat.id).with_tools(tool)
    allow(job.to_llm.provider).to receive(:complete)
      .and_return(RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1))

    job.complete

    expect(claimed).to eq([true])
  end

  it 'lets a hung call lose its claim at its own run time while the chat goes on' do
    chat = tool_call_chat
    claimed = []
    check = -> { claimed << claimed?(call_id) }
    hung = Class.new(RubyLLM::Tool) do
      define_method(:name) { 'lookup' }
      max_run_time 2
      define_method(:execute) do
        sleep 3.5
        check.call
        'found'
      end
    end
    job = Chat.find(chat.id).with_tools(hung)
    allow(job.to_llm.provider).to receive(:complete)
      .and_return(RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1))

    job.complete

    expect(claimed).to eq([false])
  end

  # The chat's claim covered the round's longest run time from when the
  # round was claimed; a call that starts later runs past that.
  it 'keeps the chat claimed for a call that starts late and has a longer run time of its own' do
    allow(RubyLLM.config).to receive(:max_run_time).and_return(3)
    chat = question_chat
    late = "call_#{SecureRandom.hex(4)}"
    tool_calls = {
      call_id => RubyLLM::ToolCall.new(id: call_id, name: 'lookup', arguments: {}),
      late => RubyLLM::ToolCall.new(id: late, name: 'report', arguments: {})
    }
    chat.add_message(role: :assistant, content: '', tool_calls:)
    running = []
    report = Class.new(RubyLLM::Tool) do
      define_method(:name) { 'report' }
      max_run_time 6
      define_method(:execute) do
        sleep 4
        running << Chat.find(chat.id).running?
        'reported'
      end
    end
    job = Chat.find(chat.id).with_tools(lookup_tool { sleep 2.5 }, report)
    allow(job.to_llm.provider).to receive(:complete)
      .and_return(RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1))

    job.complete

    expect(running).to eq([true])
    expect(roles(chat)).to eq(%w[user assistant tool tool assistant])
  end

  it 'runs a call it lost once it claims the call again' do
    chat = round_chat
    waiting = call_ids.last
    job = Chat.find(chat.id).with_tools(lookup_tool)
    taken = false
    job.after_message do |message|
      next if taken || message.role != :tool

      taken = true
      RubyLLM::ActiveRecord::ToolCall.where(tool_call_id: waiting).update_all(claimed_until: 10.minutes.from_now)
      sleep 1.5
    end
    allow(job.to_llm.provider).to receive(:complete)
      .and_return(RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1))

    job.complete
    RubyLLM::ActiveRecord::ToolCall.where(tool_call_id: waiting).update_all(claimed_until: nil)
    job.complete

    expect(executions).to eq(%i[lookup lookup])
    expect(roles(chat)).to eq(%w[user assistant tool tool assistant])
  end

  # A heartbeat renewal can land after a write that a starting tool call
  # made for a later deadline; it must not shorten the stored claim.
  it 'never moves its stored chat claim back' do
    chat = question_chat
    stored = []
    job = nil
    job = job_for(chat) do
      later = 10.minutes.from_now.change(usec: 0)
      Chat.where(id: chat.id).update_all(claimed_until: later)
      job.send(:renew_run_claim_lease, Time.current)
      job.send(:write_run_claim, Time.current)
      stored << (Chat.where(id: chat.id).pick(:claimed_until) == later)
    end

    job.complete

    expect(stored).to eq([true])
  end

  it 'never renews a claim another process took over' do
    chat = question_chat
    taken = 10.minutes.from_now.change(usec: 0)
    job = job_for(chat) do
      Chat.where(id: chat.id).update_all(claim_token: 'elsewhere', claimed_until: taken)
      sleep 0.5
    end

    job.complete

    expect(Chat.where(id: chat.id).pick(:claim_token, :claimed_until)).to eq(['elsewhere', taken])
    expect(roles(chat)).to eq(%w[user])
  end

  it 'stops renewing when the run ends, however it ends' do
    outcomes = []
    job_for(question_chat) { outcomes << heartbeats.size }.complete
    outcomes << heartbeats.size
    failing = job_for(question_chat) { raise RubyLLM::ServerError, 'boom' }
    expect { failing.complete }.to raise_error(RubyLLM::ServerError)
    outcomes << heartbeats.size
    taken = question_chat
    job_for(taken) { Chat.where(id: taken.id).update_all(claim_token: 'elsewhere') }.complete
    outcomes << heartbeats.size
    busy = question_chat
    Chat.where(id: busy.id).update_all(claim_token: 'elsewhere', claimed_until: 1.minute.from_now)
    job_for(busy).complete
    outcomes << heartbeats.size
    cancelling = nil
    cancelling = Chat.find(tool_call_chat.id).with_tools(lookup_tool { cancelling.cancel })
    expect { cancelling.complete }.to raise_error(RubyLLM::CancelledError)
    outcomes << heartbeats.size

    expect(outcomes).to eq([1, 0, 0, 0, 0, 0])
  end

  it 'stops renewing when claiming tool calls fails outside a run' do
    job = job_for(tool_call_chat)
    tool_call = RubyLLM::ToolCall.new(id: call_id, name: 'lookup', arguments: {})
    allow(job).to receive(:tool_call_rows).and_raise(ActiveRecord::StatementInvalid, 'gone')

    expect { job.claim_persisted_tool_calls({ tool_call => 60 }, executing: [call_id]) }
      .to raise_error(ActiveRecord::StatementInvalid)
    expect(heartbeats).to be_empty
  end

  it 'claims until the run time when it runs inside a transaction' do
    freeze_time
    chat = question_chat
    claims = []
    job = job_for(chat) { claims << [Chat.find(chat.id).claimed_until, heartbeats.size] }

    Chat.transaction { job.complete }

    expect(claims).to eq([[RubyLLM.config.max_run_time.seconds.from_now, 0]])
  ensure
    travel_back
  end
end
