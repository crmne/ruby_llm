# frozen_string_literal: true

require 'rails_helper'
require 'active_support/testing/time_helpers'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'
  include ActiveSupport::Testing::TimeHelpers

  let(:call_id) { "call_#{SecureRandom.hex(4)}" }
  let(:executions) { [] }
  let(:requests) { [] }
  let(:during_run) { [] }
  let(:charge_tool) { tool_class }

  def tool_class(&declarations)
    runs = executions
    hooks = during_run
    Class.new(RubyLLM::Tool) do
      requires_approval
      class_eval(&declarations) if declarations
      define_method(:name) { 'charge_card' }
      define_method(:execute) do
        runs << :charged
        hooks.shift&.call
        'charged'
      end
    end
  end

  def approved_chat
    chat = Chat.create!(model: model_for(:openai))
    chat.add_message(role: :user, content: 'Charge the card')
    tool_calls = { call_id => RubyLLM::ToolCall.new(id: call_id, name: 'charge_card', arguments: {}) }
    chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls:))
    chat.approve(call_id)
    chat
  end

  def job_for(chat, tool = charge_tool, &during_request)
    Chat.find(chat.id).with_tools(tool).tap do |job|
      allow(job.to_llm.provider).to receive(:complete) do |*, **, &stream|
        requests << job
        during_request&.call(stream)
        RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)
      end
    end
  end

  def roles(chat)
    chat.messages_association.reload.where.not(role: 'system').pluck(:role)
  end

  def tool_call_record
    RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call_id)
  end

  def question_chat
    Chat.create!(model: model_for(:openai)).tap { |chat| chat.add_message(role: :user, content: 'Hello') }
  end

  def chunk
    RubyLLM::Chunk.new(role: :assistant, content: 'Do')
  end

  def claimed_until(chat)
    Chat.find(chat.id).claimed_until
  end

  def take_over(chat)
    Chat.where(id: chat.id).update_all(claim_token: 'elsewhere', claimed_until: 10.minutes.from_now)
  end

  def tool_call_message(id, name: 'charge_card')
    tool_calls = { id => RubyLLM::ToolCall.new(id:, name:, arguments: {}) }
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls:)
  end

  def counting_reloads(job)
    allow(job).to receive(:resync_messages).and_call_original
    job
  end

  def without_claim_columns
    connection = ActiveRecord::Base.connection
    ActiveRecord::Base.transaction do
      connection.remove_column(:chats, :claim_token)
      connection.remove_column(:chats, :claimed_until)
      connection.remove_column(:ruby_llm_tool_calls, :claimed_until)
      [Chat, RubyLLM::ActiveRecord::ToolCall].each(&:reset_column_information)
      yield
      raise ActiveRecord::Rollback
    end
  ensure
    [Chat, RubyLLM::ActiveRecord::ToolCall].each(&:reset_column_information)
  end

  it 'runs an approved tool once when two jobs complete the same chat' do
    chat = approved_chat
    first_job = job_for(chat)
    second_job = job_for(chat)

    first_job.complete
    second_job.complete

    expect(executions.size).to eq(1)
    expect(roles(chat)).to eq(%w[user assistant tool assistant])
    expect(requests).to eq([first_job])
  end

  it 'returns waiting from a job that overlaps the one running the tool' do
    chat = approved_chat
    first_job = job_for(chat)
    second_job = job_for(chat)
    overlap = {}
    during_run << lambda {
      overlap[:response] = second_job.complete
      overlap[:waiting] = second_job.waiting?
      overlap[:running] = second_job.running?
      overlap[:tool_call_running] = tool_call_record.running?
    }

    first_job.complete

    expect(overlap).to include(waiting: true, running: true, tool_call_running: true)
    expect(overlap[:response].role).to eq(:assistant)
    expect(executions.size).to eq(1)
    expect(roles(chat)).to eq(%w[user assistant tool assistant])
    expect(requests).to eq([first_job])
    expect(first_job).not_to be_running
    expect(tool_call_record).not_to be_running
    expect(tool_call_record.claimed_until).to be_nil
  end

  it 'asks the model once when two jobs complete the same question' do
    chat = Chat.create!(model: model_for(:openai))
    chat.add_message(role: :user, content: 'Hello')
    second_job = job_for(chat)
    overlap = {}
    first_job = job_for(chat) do
      overlap[:response] = second_job.complete
      overlap[:step] = second_job.step
      overlap[:generate] = second_job.generate
      overlap[:waiting] = second_job.waiting?
    end

    first_job.complete

    expect(overlap).to include(step: nil, generate: nil, waiting: true)
    expect(overlap[:response].role).to eq(:user)
    expect(requests).to eq([first_job])
    expect(roles(chat)).to eq(%w[user assistant])
  end

  it 'returns the latest message other than its instructions from a job that finds the chat busy' do
    chat = question_chat
    chat.with_instructions('Be brief')
    second_job = job_for(chat)
    responses = []
    first_job = job_for(chat) { responses << second_job.complete }

    first_job.complete

    expect(responses.map(&:content)).to eq(['Hello'])
  end

  it 'answers a question asked while another process streamed the previous answer' do
    chat = Chat.create!(model: model_for(:openai))
    chat.add_message(role: :user, content: 'Hello')
    asking = job_for(chat)
    first_job = job_for(chat) do |stream|
      stream.call(RubyLLM::Chunk.new(role: :assistant, content: 'Do'))
      asking.ask('And then?') if requests.one?
    end

    first_job.complete { |_chunk| nil }

    expect(requests).to eq([first_job, first_job])
    expect(roles(chat)).to eq(%w[user assistant user assistant])
  end

  it 'continues with an approval recorded while it finished its run' do
    chat = approved_chat
    tool_call_record.update!(approval: nil)
    first_job = job_for(chat)
    approved = false
    allow(first_job.to_llm).to receive(:complete).and_wrap_original do |original, *args|
      original.call(*args).tap do
        next if approved

        approved = true
        approving = job_for(chat)
        approving.approve(call_id)
        approving.complete
      end
    end

    first_job.complete

    expect(executions.size).to eq(1)
    expect(roles(chat)).to eq(%w[user assistant tool assistant])
    expect(requests).to eq([first_job])
  end

  it 'leaves a crashed run alone until its claim expires, then runs it again' do
    chat = approved_chat
    freeze_time
    Chat.where(id: chat.id).update_all(claim_token: 'crashed', claimed_until: 10.minutes.from_now)
    tool_call_record.update!(claimed_until: 10.minutes.from_now)

    resumed = job_for(chat)
    resumed.complete

    expect(executions).to be_empty
    expect(resumed).to be_running
    expect(resumed).to be_waiting
    expect(tool_call_record).to be_running

    travel 10.minutes + 1.second
    resumed = job_for(chat)
    resumed.complete

    expect(executions.size).to eq(1)
    expect(roles(chat)).to eq(%w[user assistant tool assistant])
    expect(resumed).not_to be_running
  ensure
    travel_back
  end

  it 'keeps its claim while a long answer streams' do
    chat = Chat.create!(model: model_for(:openai))
    chat.add_message(role: :user, content: 'Hello')
    second_job = job_for(chat)
    overlap = {}
    first_job = job_for(chat) do |stream|
      3.times do
        travel 4.minutes
        stream.call(RubyLLM::Chunk.new(role: :assistant, content: 'Do'))
      end
      overlap[:response] = second_job.complete
      overlap[:running] = second_job.running?
    end

    first_job.complete { |_chunk| nil }

    expect(overlap[:running]).to be(true)
    expect(requests).to eq([first_job])
    expect(roles(chat)).to eq(%w[user assistant])
  ensure
    travel_back
  end

  it 'discards the late result of a run whose claim expired and was taken over' do
    chat = approved_chat
    first_job = job_for(chat)
    second_job = job_for(chat)
    during_run << lambda {
      travel 11.minutes
      second_job.complete
    }

    response = first_job.complete

    expect(executions.size).to eq(2)
    expect(roles(chat)).to eq(%w[user assistant tool assistant])
    expect(requests).to eq([second_job])
    expect(response.content).to eq('Done')
    expect(first_job).to be_complete
  ensure
    travel_back
  end

  it 'skips a call another process answered since the transcript loaded' do
    chat = approved_chat
    stale_job = job_for(chat)
    Chat.find(chat.id).add_message(role: :tool, content: 'charged elsewhere', tool_call_id: call_id)

    stale_job.complete

    expect(executions).to be_empty
    expect(roles(chat)).to eq(%w[user assistant tool assistant])
    expect(chat.messages_association.where(role: 'tool').pluck(:content)).to eq(['charged elsewhere'])
  end

  it 'writes a denial when the call is denied between the decision and the claim' do
    chat = approved_chat
    job = job_for(chat)
    allow(job).to receive(:claim_persisted_tool_calls).and_wrap_original do |original, *args, **kwargs|
      RubyLLM::ActiveRecord::ToolCall.where(tool_call_id: call_id).update_all(approval: 'denied')
      original.call(*args, **kwargs)
    end

    job.complete

    expect(executions).to be_empty
    expect(chat.messages_association.find_by(role: 'tool').content).to include('denied')
    expect(roles(chat)).to eq(%w[user assistant tool assistant])
  end

  it 'writes a denial once when two jobs answer it' do
    chat = approved_chat
    tool_call_record.update!(approval: nil)
    first_job = job_for(chat)
    second_job = job_for(chat)
    chat.deny(call_id)

    first_job.complete
    second_job.complete

    expect(executions).to be_empty
    expect(roles(chat)).to eq(%w[user assistant tool assistant])
  end

  it 'refuses to deny a running call and ignores approving it again' do
    chat = approved_chat
    outcomes = {}
    during_run << lambda do
      deciding = Chat.find(chat.id)
      outcomes[:approve] = deciding.approve(call_id)
      deciding.deny(call_id)
    rescue RubyLLM::ToolCallRunningError => e
      outcomes[:deny] = e
    end

    job_for(chat).complete

    expect(outcomes[:approve]).to be_a(Chat)
    expect(outcomes[:deny].message).to eq('The charge_card tool call is already running')
    expect(tool_call_record.approval).to eq('approved')
    expect(roles(chat)).to eq(%w[user assistant tool assistant])
  end

  it 'leaves the decision on an answered call alone' do
    chat = approved_chat
    job_for(chat).complete

    chat.deny(call_id)

    expect(tool_call_record.approval).to eq('approved')
  end

  it 'claims a call for the run time its tool declares' do
    freeze_time
    long_tool = tool_class { max_run_time 2.hours }
    chat = approved_chat
    claims = {}
    during_run << lambda {
      claims[:tool_call] = tool_call_record.claimed_until
      claims[:chat] = Chat.find(chat.id).claimed_until
    }

    job_for(chat, long_tool).complete

    expect(claims[:tool_call]).to eq(2.hours.from_now)
    expect(claims[:chat]).to be >= 2.hours.from_now
  ensure
    travel_back
  end

  it 'releases its claims when the chat is cancelled during a tool call' do
    chat = approved_chat
    job = job_for(chat)
    during_run << -> { job.cancel }

    expect { job.run_tools }.to raise_error(RubyLLM::CancelledError)
    expect(job).not_to be_running
    expect(tool_call_record.claimed_until).to be_nil
    expect(tool_call_record.result).to be_nil
  end

  it 'leaves a plain chat free to run the same calls in two chats' do
    plain_chats = Array.new(2) do
      chat = RubyLLM.chat(model: model_for(:openai)).with_tools(charge_tool)
      chat.add_message(role: :user, content: 'Charge the card')
      tool_calls = { call_id => RubyLLM::ToolCall.new(id: call_id, name: 'charge_card', arguments: {}) }
      chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls:))
      chat.approve(call_id)
      allow(chat.provider).to receive(:complete).and_return(RubyLLM::Message.new(role: :assistant, content: 'Done'))
      chat
    end

    plain_chats.each(&:complete)

    expect(executions.size).to eq(2)
    expect(plain_chats.map { |chat| chat.messages.map(&:role) }).to all(eq(%i[user assistant tool assistant]))
  end

  it 'runs a call the same record makes from inside its own run' do
    chat = approved_chat
    job = job_for(chat)
    nested = []
    during_run << -> { nested << job.generate }

    job.complete

    expect(nested.map(&:content)).to eq(['Done'])
    expect(requests).to eq([job, job])
  end

  it 'reloads the transcript after another process ran the chat' do
    chat = question_chat
    stale_job = job_for(chat)
    job_for(chat).complete

    expect(stale_job.step).to be_nil
    expect(requests.size).to eq(1)
    expect(roles(chat)).to eq(%w[user assistant])
  end

  it 'keeps the loaded transcript while no other process runs the chat' do
    chat = question_chat
    job_for(chat).complete
    job = counting_reloads(job_for(chat))

    job.ask('And then?')
    job.ask('And after that?')

    expect(job).not_to have_received(:resync_messages)
    expect(job).not_to be_waiting
    expect(roles(chat)).to eq(%w[user assistant user assistant user assistant])
  end

  it 'keeps the loaded transcript when every tool call it claims is free' do
    job = counting_reloads(job_for(approved_chat))

    job.complete

    expect(job).not_to have_received(:resync_messages)
    expect(executions.size).to eq(1)
  end

  it 'keeps the loaded transcript when a run finds the chat waiting' do
    chat = question_chat
    chat.add_message(tool_call_message(call_id))
    job = counting_reloads(job_for(chat))

    job.complete
    job.add_message(tool_call_message("#{call_id}_2"))
    job.complete

    expect(job).to be_waiting
    expect(job).not_to have_received(:resync_messages)
    expect(requests).to be_empty
  end

  it 'reloads the transcript after a failed run' do
    chat = question_chat
    job = job_for(chat)
    sent = []
    attempts = 0
    allow(job.to_llm.provider).to receive(:complete) do |messages, **|
      sent << messages.map(&:content)
      raise RubyLLM::ServerError, 'overloaded' if (attempts += 1) == 1

      RubyLLM::Message.new(role: :assistant, content: 'Done')
    end

    expect { job.complete }.to raise_error(RubyLLM::ServerError)
    Chat.find(chat.id).add_message(role: :user, content: 'Are you there?')
    job.complete

    expect(sent.last).to eq(['Hello', 'Are you there?'])
  end

  it 'removes its empty answer when another process takes the chat over mid-stream' do
    freeze_time
    chat = question_chat
    job = job_for(chat) do |stream|
      stream.call(chunk)
      take_over(chat)
      travel 3.minutes
      stream.call(chunk)
    end

    response = job.complete { |_chunk| nil }

    expect(response.content).to eq('Hello')
    expect(roles(chat)).to eq(%w[user])
  ensure
    travel_back
  end

  it 'discards an answer that arrives after another process took the chat over' do
    chat = question_chat
    job = job_for(chat) { take_over(chat) }

    response = job.complete

    expect(response.content).to eq('Hello')
    expect(roles(chat)).to eq(%w[user])
  end

  it 'discards a partly saved answer that arrives after another process took the chat over' do
    chat = question_chat
    job = job_for(chat) do |stream|
      stream.call(chunk)
      take_over(chat)
    end

    job.complete { |chunk| job.messages.last.update!(content: chunk.content) }

    expect(roles(chat)).to eq(%w[user])
  end

  it 'discards a tool result another process recorded first' do
    chat = approved_chat
    during_run << lambda {
      Chat.find(chat.id).add_message(role: :tool, content: 'charged elsewhere', tool_call_id: call_id)
    }

    job_for(chat).complete

    expect(chat.messages_association.where(role: 'tool').pluck(:content)).to eq(['charged elsewhere'])
    expect(roles(chat)).to eq(%w[user assistant tool])
  end

  it 'renews its claim at most every quarter of the run time' do
    freeze_time
    chat = question_chat
    started = Time.current
    claims = []
    job = job_for(chat) do |stream|
      travel 1.minute
      stream.call(chunk)
      claims << claimed_until(chat)
      travel 90.seconds
      stream.call(chunk)
      claims << claimed_until(chat)
    end

    job.complete { |_chunk| nil }

    expect(claims).to eq([started + 10.minutes, started + 150.seconds + 10.minutes])
  ensure
    travel_back
  end

  it 'keeps the claim a long tool call extended when it renews afterwards' do
    freeze_time
    started = Time.current
    claims = []
    job = job_for(approved_chat, tool_class { max_run_time 2.hours }) do |stream|
      travel 3.minutes
      stream.call(chunk)
      claims << claimed_until(Chat.last)
    end

    job.complete { |_chunk| nil }

    expect(claims).to eq([started + 2.hours])
  ensure
    travel_back
  end

  it 'stops extending its claim for a call it already answered' do
    freeze_time
    started = Time.current
    chat = approved_chat
    claims = []
    refund = Class.new(RubyLLM::Tool) do
      requires_approval
      define_method(:name) { 'refund' }
      define_method(:execute) { claims << Chat.find(chat.id).claimed_until and 'refunded' }
    end
    job = job_for(chat, tool_class { max_run_time 2.hours }).with_tools(refund)
    job.complete
    travel 1.hour
    job.add_message(tool_call_message('refund_call', name: 'refund'))
    job.approve('refund_call')

    job.complete

    expect(claims).to eq([started + 1.hour + 10.minutes])
  ensure
    travel_back
  end

  it 'waits on a call another process is running while the chat itself is free' do
    chat = approved_chat
    tool_call_record.update!(claimed_until: 10.minutes.from_now)
    job = job_for(chat)

    job.run_tools

    expect(executions).to be_empty
    expect(job).to be_waiting
    expect(job).not_to be_running
  end

  it 'runs without claims on a schema that has no claim columns' do
    chat = approved_chat

    without_claim_columns do
      job = job_for(chat)
      job.complete

      expect(executions.size).to eq(1)
      expect(roles(chat)).to eq(%w[user assistant tool assistant])
      expect(job).not_to be_running
      expect(job).not_to be_waiting
    end
  end

  it 'leaves work another process added to a chat without claim columns to that process' do
    chat = question_chat

    without_claim_columns do
      job = job_for(chat) do |stream|
        stream.call(chunk)
        Chat.find(chat.id).add_message(role: :user, content: 'And then?')
      end
      job.complete { |_chunk| nil }

      expect(requests).to eq([job])
      expect(roles(chat)).to eq(%w[user assistant user])
    end
  end

  it 'releases an unanswered call on a schema that has no claim columns' do
    chat = approved_chat

    without_claim_columns do
      job = job_for(chat)
      during_run << -> { job.cancel }

      expect { job.run_tools }.to raise_error(RubyLLM::CancelledError)
      expect(tool_call_record.result).to be_nil
    end
  end
end
