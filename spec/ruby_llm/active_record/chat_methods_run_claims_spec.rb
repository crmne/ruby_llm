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

  it 'runs without claims on a schema that has no claim columns' do
    chat = approved_chat
    connection = ActiveRecord::Base.connection

    ActiveRecord::Base.transaction do
      connection.remove_column(:chats, :claim_token)
      connection.remove_column(:chats, :claimed_until)
      connection.remove_column(:ruby_llm_tool_calls, :claimed_until)
      [Chat, RubyLLM::ActiveRecord::ToolCall].each(&:reset_column_information)

      job = job_for(chat)
      job.complete

      expect(executions.size).to eq(1)
      expect(roles(chat)).to eq(%w[user assistant tool assistant])
      expect(job).not_to be_running
      raise ActiveRecord::Rollback
    end
  ensure
    [Chat, RubyLLM::ActiveRecord::ToolCall].each(&:reset_column_information)
  end
end
