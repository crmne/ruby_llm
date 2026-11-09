# frozen_string_literal: true

require 'rails_helper'
require 'active_support/testing/time_helpers'

# A process that exits without unwinding, as a Solid Queue worker does once
# its shutdown timeout passes, can't expire its claims as it stops, so it
# ends them by the time it exits instead.
RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'
  include ActiveSupport::Testing::TimeHelpers

  let(:executions) { [] }
  let(:call_ids) { Array.new(2) { "call_#{SecureRandom.hex(4)}" } }

  before { stub_const('RubyLLM::ActiveRecord::RunClaims::CLAIM_RENEWAL', 0.2) }

  after do
    travel_back
    RubyLLM::ActiveRecord::RunClaims.instance_variable_set(:@exit_deadline, nil)
  end

  def exits_by(time)
    RubyLLM::ActiveRecord::RunClaims.process_exits_by(time)
  end

  def exit_deadline
    RubyLLM::ActiveRecord::RunClaims.exit_deadline
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

  def reply
    RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)
  end

  def job_for(chat, tool = lookup_tool, &during_request)
    Chat.find(chat.id).with_tools(tool).tap do |job|
      allow(job.to_llm.provider).to receive(:complete) do
        during_request&.call
        reply
      end
    end
  end

  def question_chat
    Chat.create!(model: model_for(:openai)).tap { |chat| chat.add_message(role: :user, content: 'Hello') }
  end

  def round_chat(ids = call_ids)
    question_chat.tap do |chat|
      tool_calls = ids.to_h { |id| [id, RubyLLM::ToolCall.new(id:, name: 'lookup', arguments: {})] }
      chat.add_message(role: :assistant, content: '', tool_calls:)
    end
  end

  def tool_call_record(tool_call_id = call_ids.first)
    RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id:)
  end

  def interrupted?(chat)
    Chat.interrupted.exists?(chat.id)
  end

  # Runs +work+ in a forked process, which tells the parent when it is busy
  # with the moment its claims end by, and is ended with a SIGKILL, which
  # unwinds nothing, as Solid Queue's exit! after its shutdown timeout.
  def exiting_process(&work)
    skip 'needs fork' unless Process.respond_to?(:fork)

    reader, writer = IO.pipe
    pid = fork do
      reader.close
      work.call(->(deadline) { writer.puts(deadline.to_f) })
    ensure
      exit!(0)
    end
    writer.close
    [pid, Time.zone.at(reader.gets.to_f)]
  ensure
    reader&.close
  end

  def kill(pid)
    Process.kill(:KILL, pid)
    Process.wait(pid)
  end

  def within?(seconds)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    loop do
      return true if yield
      return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  end

  it 'ends the claim of a chat whose model is still answering by the time its process exits' do
    chat = question_chat
    pid, deadline = exiting_process do |busy|
      job_for(chat) do
        exits_by(2.seconds.from_now)
        busy.call(exit_deadline)
        sleep
      end.complete
    end

    expect(within?(1) { Chat.find(chat.id).claimed_until <= deadline }).to be(true)
    expect(Chat.find(chat.id)).to be_running

    kill(pid)

    expect(within?(3) { interrupted?(chat) }).to be(true)
    expect(Time.current).to be < deadline + 2
  end

  it 'answers the tool call that was running at the exit as interrupted, without running it again' do
    chat = round_chat([call_ids.first])
    pid, deadline = exiting_process do |busy|
      job_for(chat, lookup_tool do
        exits_by(2.seconds.from_now)
        busy.call(exit_deadline)
        sleep
      end).complete
    end

    expect(within?(1) { tool_call_record.claimed_until <= deadline }).to be(true)
    expect(tool_call_record).to be_running

    kill(pid)

    expect(within?(3) { interrupted?(chat) && !tool_call_record.running? }).to be(true)

    job_for(chat).complete

    expect(executions).to be_empty
    expect(tool_call_record.result.content).to include('may have partly run')
  end

  it 'releases its claims as usual when the run finishes before the exit' do
    chat = round_chat([call_ids.first])

    job_for(chat, lookup_tool { exits_by(5.seconds.from_now) }).complete

    expect(Chat.find(chat.id)).to have_attributes(claim_token: nil, claimed_until: nil)
    expect(tool_call_record).to have_attributes(claimed_until: nil, result: be_present)
    expect(executions).to eq([:lookup])
  end

  it 'claims a chat only until the exit once the process is exiting' do
    chat = question_chat
    exits_by(3.seconds.from_now)
    claimed = []

    job_for(chat) { claimed << Chat.find(chat.id).claimed_until }.complete

    expect(claimed.sole).to eq(exit_deadline)
  end

  it 'claims a tool call that starts once the process is exiting only until the exit' do
    chat = round_chat
    started = []
    job_for(chat, lookup_tool do
      exits_by(3.seconds.from_now) if started.empty?
      started << tool_call_record(call_ids[started.size]).claimed_until
    end).complete

    expect(started.last).to eq(exit_deadline)
  end

  it 'ends the claim of a call waiting for its turn by the exit as well' do
    chat = round_chat
    waiting = []
    job_for(chat, lookup_tool do
      next unless waiting.empty?

      exits_by(3.seconds.from_now)
      waiting << within?(1) { tool_call_record(call_ids.last).claimed_until == exit_deadline }
    end).complete

    expect(waiting).to eq([true])
  end

  it 'ends a claim another thread extended past the exit, at the next beat' do
    chat = question_chat
    after_beat = []
    job_for(chat) do
      exits_by(3.seconds.from_now)
      within?(1) { Chat.find(chat.id).claimed_until <= exit_deadline }
      Chat.where(id: chat.id).update_all(claimed_until: 1.minute.from_now)
      after_beat << within?(2) { Chat.find(chat.id).claimed_until == exit_deadline }
    end.complete

    expect(after_beat).to eq([true])
  end

  it 'keeps the earliest exit it was told of, to the whole second' do
    travel_to Time.current.change(usec: 900_000), with_usec: true
    exits_by(5.seconds.from_now)
    exits_by(9.seconds.from_now)

    expect(exit_deadline).to eq(5.seconds.from_now.change(usec: 0))

    exits_by(2.seconds.from_now)

    expect(exit_deadline).to eq(2.seconds.from_now.change(usec: 0))
  end
end
