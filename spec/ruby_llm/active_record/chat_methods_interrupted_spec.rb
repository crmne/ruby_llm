# frozen_string_literal: true

require 'rails_helper'
require 'active_support/testing/time_helpers'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'
  include ActiveSupport::Testing::TimeHelpers

  after { travel_back }

  let(:lease) { RubyLLM::ActiveRecord::RunClaims::CLAIM_LEASE.seconds }
  let(:created) { [] }

  # Other examples leave their chats in the database, so each example
  # looks only at its own.
  def chats
    Chat.where(id: created.map(&:id))
  end

  def chat_with(*messages)
    Chat.create!(model: model_for(:openai)).tap do |chat|
      created << chat
      messages.each { |message| chat.add_message(message) }
    end
  end

  def claim(chat, until_time)
    Chat.where(id: chat.id).update_all(claim_token: 'worker', claimed_until: until_time)
    chat
  end

  def asked
    chat_with({ role: :user, content: 'Hello' })
  end

  def answered
    chat_with({ role: :user, content: 'Hello' }, { role: :assistant, content: 'Hi', finish_reason: 'stop' })
  end

  def call(name = 'lookup')
    RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name:, arguments: {})
  end

  def mid_round(first = call, second = call)
    chat = chat_with({ role: :user, content: 'Look twice' },
                     { role: :assistant, content: '', tool_calls: { first.id => first, second.id => second } })
    chat.add_message(role: :tool, content: 'found', tool_call_id: first.id)
    [chat, second]
  end

  def tool_call_row(tool_call)
    RubyLLM::ActiveRecord::ToolCall.where(tool_call_id: tool_call.id)
  end

  describe '.interrupted' do
    it 'returns a chat whose reply was cut off after the user asked' do
      chat = claim(asked, 1.minute.ago)

      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'returns a chat that never held a claim' do
      chat = asked

      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'returns a chat once its lease expires' do
      chat = claim(asked, lease.from_now)

      expect(chats.interrupted).to be_empty
      travel lease + 1
      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'looks past the blank reply a killed run leaves' do
      chat = asked
      chat.messages.create!(role: :assistant, content: '')

      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'returns a chat whose tool round is unfinished' do
      chat, = mid_round

      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'returns a chat whose tool round finished before the model answered' do
      tool_call = call
      chat = chat_with({ role: :user, content: 'Look' },
                       { role: :assistant, content: '', tool_calls: { tool_call.id => tool_call } })
      chat.add_message(role: :tool, content: 'found', tool_call_id: tool_call.id)

      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'returns a chat whose call was answered but never ran' do
      chat, second = mid_round
      tool_call_row(second).update_all(mcp_state: { 'requests' => [{ 'id' => 'q1', 'response' => 'yes' }] })

      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'returns a chat whose call was approved but never ran' do
      chat, second = mid_round
      tool_call_row(second).update_all(approval: 'approved')

      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'returns a chat whose stream the provider paused' do
      chat = asked
      chat.messages.create!(role: :assistant, content: 'Half', continuation: 'resume-token')

      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'returns an answered chat with a message still queued' do
      chat = answered
      chat.queue('And then?')

      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'returns a chat whose worker died during a tool round, once its claims expire' do
      chat, second = mid_round
      chat.messages.create!(role: :assistant, content: '')
      claim(chat, lease.from_now)
      tool_call_row(second).update_all(claimed_until: lease.from_now)

      expect(chats.interrupted).to be_empty
      travel lease + 1
      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'returns none without the claim columns, since no row says whether a run holds a chat' do
      asked
      allow(Chat).to receive(:column_names).and_return(Chat.column_names - %w[claim_token claimed_until])

      expect(chats.interrupted).to be_empty
    end

    it 'counts a reply with only thinking as an answer' do
      chat = asked
      chat.messages.create!(role: :assistant, content: '', thinking_text: 'Nothing to add', finish_reason: 'stop')

      expect(chats.interrupted).to be_empty
    end

    it 'counts a reply with only an attachment as an answer' do
      chat = asked
      reply = chat.messages.create!(role: :assistant, content: '', finish_reason: 'stop')
      reply.attachments.attach(io: StringIO.new('chart'), filename: 'chart.txt', content_type: 'text/plain')

      expect(chats.interrupted).to be_empty
    end

    it 'treats every tool result as needing a reply without a finish_reason column' do
      tool_call = call
      chat = chat_with({ role: :user, content: 'Look' },
                       { role: :assistant, content: '', tool_calls: { tool_call.id => tool_call } })
      chat.add_message(role: :tool, content: 'done', tool_call_id: tool_call.id, finish_reason: 'halted')
      allow(Message).to receive(:column_names).and_return(Message.column_names - %w[finish_reason])

      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'pauses no call without an mcp_state column' do
      chat, second = mid_round
      tool_call_row(second).update_all(mcp_state: { 'requests' => [{ 'id' => 'q1', 'message' => 'Sure?' }] })
      allow(RubyLLM::ActiveRecord::ToolCall).to receive(:column_names)
        .and_return(RubyLLM::ActiveRecord::ToolCall.column_names - %w[mcp_state])

      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'leaves out complete chats' do
      answered
      created << Chat.create!(model: model_for(:openai))

      expect(chats.interrupted).to be_empty
    end

    it 'leaves out a chat a tool halted' do
      tool_call = call
      chat = chat_with({ role: :user, content: 'Look' },
                       { role: :assistant, content: '', tool_calls: { tool_call.id => tool_call } })
      chat.add_message(role: :tool, content: 'done', tool_call_id: tool_call.id, finish_reason: 'halted')

      expect(chats.interrupted).to be_empty
    end

    it 'leaves out a chat a tool halted before another call of its round finished' do
      chat, second = mid_round
      first_result = chat.messages.where(role: 'tool').last
      first_result.update!(finish_reason: 'halted')
      chat.add_message(role: :tool, content: 'found', tool_call_id: second.id)

      expect(chats.interrupted).to be_empty
    end

    it 'leaves out cancelled chats' do
      chat = asked
      Chat.where(id: chat.id).update_all(cancelled: true)

      expect(chats.interrupted).to be_empty
    end

    it 'leaves out chats a run holds' do
      claim(asked, lease.from_now)
      claim(mid_round.first, lease.from_now)

      expect(chats.interrupted).to be_empty
    end

    it 'leaves out a chat whose only open call another process is running' do
      chat, second = mid_round
      tool_call_row(second).update_all(claimed_until: lease.from_now)

      expect(chats.interrupted).to be_empty
      travel lease + 1
      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'leaves out a chat waiting for an approval' do
      _, second = mid_round
      tool_call_row(second).update_all(approval: 'pending')

      expect(chats.interrupted).to be_empty
    end

    it 'leaves out a chat waiting for an answer' do
      _, second = mid_round
      tool_call_row(second).update_all(mcp_state: { 'requests' => [{ 'id' => 'q1', 'message' => 'Sure?' }] })

      expect(chats.interrupted).to be_empty
    end

    it 'leaves out a chat waiting on a task' do
      _, second = mid_round
      tool_call_row(second).update_all(mcp_state: { 'task' => { 'id' => 't1', 'status' => 'working' } })

      expect(chats.interrupted).to be_empty
    end

    it 'returns a chat with one call waiting and another free to run' do
      first = call
      second = call
      chat = chat_with({ role: :user, content: 'Look twice' },
                       { role: :assistant, content: '', tool_calls: { first.id => first, second.id => second } })
      tool_call_row(first).update_all(approval: 'pending')

      expect(chats.interrupted).to contain_exactly(chat)
    end

    it 'ignores open calls on an earlier response' do
      tool_call = call
      chat_with({ role: :user, content: 'Look' },
                { role: :assistant, content: '', tool_calls: { tool_call.id => tool_call } },
                { role: :assistant, content: 'Never mind', finish_reason: 'stop' })

      expect(chats.interrupted).to be_empty
    end

    it 'agrees with complete? and waiting? on every chat' do
      asked
      answered
      mid_round
      claim(asked, 1.minute.ago)
      claim(asked, lease.from_now)
      _, guarded_call = mid_round(call, call('guarded'))
      tool_call_row(guarded_call).update_all(approval: 'pending')
      guarded = Class.new(RubyLLM::Tool) do
        define_method(:name) { 'guarded' }
        requires_approval
      end

      settled = chats.select { |chat| chat.with_tools(guarded).then { |record| record.complete? || record.waiting? } }

      expect(chats.interrupted).to match_array(chats - settled)
    end

    it 'composes with other conditions' do
      chat = asked
      asked

      expect(Chat.where(id: chat.id).interrupted).to contain_exactly(chat)
      expect(Chat.interrupted.where(id: chat.id)).to contain_exactly(chat)
      expect(Chat.interrupted.merge(chats).count).to eq(2)
    end

    it 'keeps a selection the caller made' do
      chat, second = mid_round
      tool_call_row(second).update_all(mcp_state: { 'requests' => [{ 'id' => 'q1', 'response' => 'yes' }] })

      expect(chats.select(:id).interrupted.map(&:id)).to eq([chat.id])
    end

    it 'loads in batches' do
      interrupted = Array.new(3) { asked }
      answered

      expect(chats.interrupted.find_each(batch_size: 2).to_a).to match_array(interrupted)
    end
  end
end
