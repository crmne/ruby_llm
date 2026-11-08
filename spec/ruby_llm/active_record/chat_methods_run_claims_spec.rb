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

  it 'keeps contested tool calls apart on a copy of the underlying chat' do
    record = instance_double(Chat, claim_persisted_tool_calls: [], tool_call_running_elsewhere?: true)
    state = RubyLLM::ActiveRecord::ChatToolCallState.new(record)
    tool_call = RubyLLM::ToolCall.new(id: 'call_1', name: 'deploy', arguments: {})
    state.claim(['call_1'], executing: []) { { tool_call => 60 } }
    copy = state.dup

    copy.claim([], executing: [])

    expect(state).to be_running_elsewhere(tool_call)
    expect(copy).not_to be_running_elsewhere(tool_call)
  end

  it 'observes a cancellation another process requested on a copy of the underlying chat' do
    chat = Chat.create!(model: model_for(:openai, :temperature))
    copy = chat.to_llm.dup
    Chat.where(id: chat.id).update_all(cancelled: true)

    expect { copy.__send__(:raise_if_cancelled!) }.to raise_error(RubyLLM::CancelledError)
    expect(chat.reload[:cancelled]).to be(false)
  end

  it 'records usage on the record from a copy of the underlying chat' do
    chat = Chat.create!(model: model_for(:openai, :temperature))
    entry = RubyLLM::Accounting::Usage::Entry.new(operation: :chat, provider: 'openai',
                                                  model: model_for(:openai, :temperature))

    expect { chat.to_llm.dup.__send__(:record_usage_entry, entry) }.to change { chat.ruby_llm_usages.reset.size }.by(1)
  end

  it 'binds a copy of the record to its own run' do
    chat = Chat.create!(model: model_for(:openai, :temperature))
    chat.to_llm

    copy = chat.dup

    expect(copy.to_llm.instance_variable_get(:@run).instance_variable_get(:@chat)).to be(copy)
  end

  it 'leaves a claim and a pending cancel behind on a dup' do
    chat = Chat.create!(model: model_for(:openai))
    Chat.where(id: chat.id).update_all(claim_token: 'other', claimed_until: 10.minutes.from_now, cancelled: true)

    copy = Chat.find(chat.id).dup
    copy.save!

    expect(copy).not_to be_running
    expect(copy).to have_attributes(claim_token: nil, claimed_until: nil, cancelled: false)
  end

  it 'reads tokens another process recorded after a takeover' do
    chat = Chat.create!(model: model_for(:openai))
    chat.add_message(role: :user, content: 'Hello')
    chat.to_llm
    chat.tokens
    job_for(chat).complete

    chat.send(:resync_messages)

    expect(chat.tokens.input).to eq(1)
    expect(chat.to_llm.usage_entries.size).to eq(1)
  end

  it 'reads usage outside the query cache when it refreshes' do
    chat = Chat.create!(model: model_for(:openai))
    cached = []
    record = ->(*, payload) { cached << payload[:cached] if payload[:sql].include?('ruby_llm_usages') }

    Chat.cache do
      chat.tokens
      ActiveSupport::Notifications.subscribed(record, 'sql.active_record') do
        chat.refresh_messages
        chat.tokens
      end
    end

    expect(cached.compact).to be_empty
  end

  it 'drops what the failed round destroyed from the transcript in memory' do
    first = RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name: 'charge_card', arguments: {})
    second = RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name: 'charge_card', arguments: {})
    chat = Chat.create!(model: model_for(:openai)).with_tools(charge_tool)
    chat.add_message(role: :user, content: 'Charge twice')
    chat.add_message(RubyLLM::Message.new(role: :assistant, content: '',
                                          tool_calls: { first.id => first, second.id => second }))
    chat.add_message(role: :tool, content: 'charged', tool_call_id: first.id)
    chat.approve(second.id)
    during_run << -> { raise RubyLLM::ServerError, 'boom' }

    expect { chat.complete }.to raise_error(RubyLLM::ServerError)
    expect(chat.messages_association.reload.map(&:role)).to eq(['user'])
    expect(chat.to_llm.messages.map(&:role)).to eq([:user])
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
      connection.remove_index(:chats, :claimed_until)
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

  it 'sends a question saved between loading the chat and claiming it' do
    chat = question_chat
    job = Chat.find(chat.id)
    sent = []
    allow(job.to_llm.provider).to receive(:complete) do |messages, **|
      sent << messages.map(&:content)
      RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)
    end
    Chat.find(chat.id).ask_later('And then?')

    job.complete

    expect(sent).to eq([['Hello', 'And then?']])
    expect(Chat.find(chat.id)).to be_complete
  end

  it 'rereads a chat another process claimed, even with no new message' do
    chat = question_chat
    job = job_for(chat)
    Chat.where(id: chat.id).update_all(claim_token: 'other', claimed_until: nil)
    allow(job).to receive(:resync_messages).and_call_original

    job.complete

    expect(job).to have_received(:resync_messages).once
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

  it 'clears a cancel that arrived after its run last checked, so the next turn runs' do
    chat = question_chat
    first_job = job_for(chat)
    first_job.after_message { Chat.where(id: chat.id).update_all(cancelled: true) }
    first_job.complete
    next_job = job_for(chat)

    next_job.ask('And then?')

    expect(requests).to eq([first_job, next_job])
    expect(Chat.find(chat.id)[:cancelled]).to be(false)
  end

  it 'clears a cancel the record itself requested after its run last checked' do
    job = job_for(question_chat)
    job.after_message { job.cancel if requests.one? }
    job.complete

    job.ask('And then?')

    expect(requests).to eq([job, job])
    expect(job).not_to be_cancelled
  end

  it 'keeps a cancel aimed at the run of the process that took the chat over' do
    chat = question_chat

    job_for(chat) do
      take_over(chat)
      Chat.where(id: chat.id).update_all(cancelled: true)
    end.complete

    expect(Chat.find(chat.id)[:cancelled]).to be(true)
  end

  it 'does not fall back when another process takes over the run' do
    chat = question_chat
    fallback = stub_request(:post, 'https://api.anthropic.com/v1/messages').to_return(status: 500)
    job = job_for(chat) { take_over(chat) }.with_fallbacks(model_for(:anthropic), on: StandardError)

    job.complete

    expect(requests).to eq([job])
    expect(fallback).not_to have_been_requested
    expect(job.to_llm.model.id).to eq(model_for(:openai))
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
    tool_call_record.update!(approval: 'pending')
    first_job = job_for(chat)
    second_job = job_for(chat)
    chat.decline(call_id)

    first_job.complete
    second_job.complete

    expect(executions).to be_empty
    expect(roles(chat)).to eq(%w[user assistant tool assistant])
  end

  it 'ignores declining a running call and approving it again' do
    chat = approved_chat
    outcomes = {}
    during_run << lambda do
      deciding = Chat.find(chat.id)
      outcomes[:approve] = deciding.approve(call_id)
      outcomes[:decline] = deciding.decline(call_id)
    end

    job_for(chat).complete

    expect(outcomes.values).to all(be_a(Chat))
    expect(tool_call_record.approval).to eq('approved')
    expect(roles(chat)).to eq(%w[user assistant tool assistant])
  end

  it 'leaves the decision on an answered call alone' do
    chat = approved_chat
    job_for(chat).complete

    chat.decline(call_id)

    expect(tool_call_record.approval).to eq('approved')
  end

  it 'renews the claims on a call for the run time its tool declares, and no longer' do
    freeze_time
    started = Time.current
    chat = approved_chat
    job = job_for(chat, tool_class { max_run_time 2.hours })
    claims = []
    record_claims = -> { claims << [tool_call_record.claimed_until, Chat.find(chat.id).claimed_until] }
    during_run << lambda {
      record_claims.call
      [90.minutes, 29.minutes + 30.seconds, 1.minute].each do |wait|
        travel wait
        job.__send__(:renew_claim_leases)
        record_claims.call
      end
    }

    job.complete

    expect(claims).to eq([[started + 1.minute] * 2, [started + 91.minutes] * 2] + ([[started + 2.hours] * 2] * 2))
  ensure
    travel_back
  end

  it 'releases its claims and keeps the result when the chat is cancelled during a tool call' do
    chat = approved_chat
    job = job_for(chat)
    during_run << -> { job.cancel }

    expect { job.run_tools }.to raise_error(RubyLLM::CancelledError)
    expect(job).not_to be_running
    expect(tool_call_record.claimed_until).to be_nil
    expect(tool_call_record.result).to be_present
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

  it 'discards an answer when another process takes the chat over just before it is saved' do
    chat = question_chat
    job = job_for(chat)
    allow(job).to receive(:message_attributes).and_wrap_original do |original, *args|
      take_over(chat)
      original.call(*args)
    end

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

  it 'renews its lease as it streams, at most every quarter of the lease' do
    freeze_time
    chat = question_chat
    started = Time.current
    claims = []
    job = job_for(chat) do |stream|
      travel 10.seconds
      stream.call(chunk)
      claims << claimed_until(chat)
      travel 10.seconds
      stream.call(chunk)
      claims << claimed_until(chat)
    end

    job.complete { |_chunk| nil }

    expect(claims).to eq([started + 1.minute, started + 20.seconds + 1.minute])
  ensure
    travel_back
  end

  it 'renews within a run time shorter than the lease as it streams' do
    allow(RubyLLM.config).to receive(:max_run_time).and_return(8)
    freeze_time
    chat = question_chat
    started = Time.current
    claims = []
    job = job_for(chat) do |stream|
      travel 3.seconds
      stream.call(chunk)
      claims << claimed_until(chat)
    end

    job.complete { |_chunk| nil }

    expect(claims).to eq([started + 11.seconds])
  ensure
    travel_back
  end

  it 'keeps renewing its lease until the run time a long tool call extended' do
    freeze_time
    started = Time.current
    claims = []
    chat = approved_chat
    job = job_for(chat, tool_class { max_run_time 2.hours }) do |stream|
      travel 3.minutes
      stream.call(chunk)
      travel 30.minutes
      job.__send__(:renew_claim_leases)
      claims << claimed_until(chat)
    end

    job.complete { |_chunk| nil }

    expect(claims).to eq([started + 33.minutes + 1.minute])
  ensure
    travel_back
  end

  it 'stops renewing its lease once the model is silent for longer than the run time' do
    freeze_time
    started = Time.current
    chat = question_chat
    second_job = job_for(chat)
    claims = []
    job = job_for(chat) do
      travel 9.minutes + 30.seconds
      job.__send__(:renew_claim_leases)
      claims << claimed_until(chat)
      travel 1.minute
      job.__send__(:renew_claim_leases)
      claims << claimed_until(chat)
      second_job.complete
    end

    job.complete

    expect(claims).to eq([started + 10.minutes, started + 10.minutes])
    expect(requests).to eq([job, second_job])
    expect(roles(chat)).to eq(%w[user assistant])
  ensure
    travel_back
  end

  it 'stops extending its claim for a call it already answered' do
    freeze_time
    started = Time.current
    chat = approved_chat
    claims = []
    job = nil
    renew_later = lambda {
      travel 15.minutes
      job.__send__(:renew_claim_leases)
    }
    refund = Class.new(RubyLLM::Tool) do
      requires_approval
      define_method(:name) { 'refund' }
      define_method(:execute) do
        renew_later.call
        claims << Chat.find(chat.id).claimed_until
        'refunded'
      end
    end
    job = job_for(chat, tool_class { max_run_time 2.hours }).with_tools(refund)
    job.complete
    travel 1.hour
    job.add_message(tool_call_message('refund_call', name: 'refund'))
    job.approve('refund_call')

    job.complete

    expect(claims).to eq([started + 1.hour + 1.minute])
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

  it 'keeps a finished call on a schema that has no claim columns' do
    chat = approved_chat

    without_claim_columns do
      job = job_for(chat)
      during_run << -> { job.cancel }

      expect { job.run_tools }.to raise_error(RubyLLM::CancelledError)
      expect(tool_call_record.result).to be_present
    end
  end
end
