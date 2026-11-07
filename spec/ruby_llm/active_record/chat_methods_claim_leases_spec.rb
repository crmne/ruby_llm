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

  def roles(chat)
    chat.messages_association.reload.pluck(:role)
  end

  def heartbeats
    Thread.list.select { |thread| thread.alive? && thread.name == 'ruby_llm claim heartbeat' }
  end

  # Runs +work+ in a forked process, waits until it reports that it is
  # busy, and returns its pid.
  def busy_process(&work)
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
