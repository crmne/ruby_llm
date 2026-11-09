# frozen_string_literal: true

require 'rails_helper'
require 'active_support/testing/time_helpers'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'
  include ActiveSupport::Testing::TimeHelpers

  after { travel_back }

  let(:executions) { [] }
  let(:requests) { [] }
  let(:first_call) { "call_#{SecureRandom.hex(4)}" }
  let(:second_call) { "call_#{SecureRandom.hex(4)}" }
  let(:lookup_tool) do
    runs = executions
    Class.new(RubyLLM::Tool) do
      define_method(:name) { 'lookup' }
      define_method(:execute) do
        runs << :lookup
        'found'
      end
    end
  end

  # What a worker leaves when it dies after one of two tools finished and
  # before the placeholder for its result was filled: its claims on the
  # chat and on the unfinished call outlive it by up to a lease.
  def crashed_chat(*later_questions)
    chat = Chat.create!(model: model_for(:openai))
    chat.add_message(role: :user, content: 'Look twice')
    calls = [first_call, second_call].to_h { |id| [id, RubyLLM::ToolCall.new(id:, name: 'lookup', arguments: {})] }
    chat.add_message(role: :assistant, content: '', tool_calls: calls)
    chat.add_message(role: :tool, content: 'found', tool_call_id: first_call)
    placeholder = chat.messages.create!(role: :assistant, content: '')
    later_questions.each { |question| chat.messages.create!(role: :user, content: question) }
    claimed_until = RubyLLM::ActiveRecord::RunClaims::CLAIM_LEASE.seconds.from_now
    Chat.where(id: chat.id).update_all(claim_token: 'crashed', claimed_until:)
    RubyLLM::ActiveRecord::ToolCall.where(tool_call_id: second_call).update_all(claimed_until:)
    [chat, placeholder]
  end

  def resumed(chat)
    Chat.find(chat.id).with_tools(lookup_tool).tap do |record|
      allow(record.to_llm.provider).to receive(:complete) do |messages, **|
        requests << messages
        RubyLLM::Message.new(role: :assistant, content: 'Answered', input_tokens: 1, output_tokens: 1)
      end
    end
  end

  def sent
    requests.last.map { |message| [message.role, message.content, message.tool_call_id].compact }
  end

  def result_of(tool_call_id)
    RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id:).result
  end

  it 'waits for the claims of the crashed worker to expire' do
    chat, = crashed_chat
    chat = resumed(chat)

    chat.complete

    expect(executions).to be_empty
    expect(requests).to be_empty
    expect(chat).to be_running
    expect(chat).to be_waiting
  end

  # The crashed worker may have run the call before it died, so the model
  # hears it was interrupted rather than the call running twice.
  it 'answers the unfinished call as interrupted once the claims expire, without running it again' do
    chat, placeholder = crashed_chat
    travel RubyLLM::ActiveRecord::RunClaims::CLAIM_LEASE + 1
    chat = resumed(chat)
    interrupted = { error: 'The tool call did not finish. ' \
                           'The call may have partly run, so check before trying it again.' }.to_json

    expect(chat.complete.content).to eq('Answered')
    expect(executions).to be_empty
    expect(sent).to eq([[:user, 'Look twice'], [:assistant, ''], [:tool, 'found', first_call],
                        [:tool, interrupted, second_call]])
    expect(result_of(second_call).content).to eq(interrupted)
    expect(Message.exists?(placeholder.id)).to be(false)
  end

  # What a worker leaves when it is killed while the reply streams: the
  # blank placeholder the reply streamed into, and its claim on the chat.
  def killed_stream_chat
    chat = Chat.create!(model: model_for(:openai))
    chat.add_message(role: :user, content: 'Hello')
    placeholder = chat.messages.create!(role: :assistant, content: '')
    Chat.where(id: chat.id).update_all(claim_token: 'killed', claimed_until: 1.second.ago)
    [chat, placeholder]
  end

  it 'replaces the blank placeholder of a killed stream with the resumed reply' do
    chat, placeholder = killed_stream_chat
    chat = resumed(chat)

    expect(chat.complete.content).to eq('Answered')
    expect(Message.exists?(placeholder.id)).to be(false)
    expect(Chat.find(chat.id).messages.order(:id).map { |message| [message.role, message.content] })
      .to eq([%w[user Hello], %w[assistant Answered]])
  end

  it 'keeps a blank reply that recorded usage when the next run writes after it' do
    chat, placeholder = killed_stream_chat
    chat.ruby_llm_usages.create!(message: placeholder, operation: 'chat', provider: 'openai', model: 'gpt-4.1',
                                 status: 'succeeded')
    chat = resumed(chat)

    chat.send(:exclusively, -> {}) { chat.send(:persist_new_message) }

    expect(Message.exists?(placeholder.id)).to be(true)
  end

  it 'keeps a reply that saved only its thinking when the next run writes after it' do
    chat, placeholder = killed_stream_chat
    placeholder.update!(thinking_text: 'Pondering')
    chat = resumed(chat)

    chat.send(:exclusively, -> {}) { chat.send(:persist_new_message) }

    expect(Message.exists?(placeholder.id)).to be(true)
  end

  it 'leaves the placeholder of the run that took the chat over to it' do
    chat, = killed_stream_chat
    chat = resumed(chat)
    placeholder = nil

    chat.send(:exclusively, -> {}) do
      Chat.where(id: chat.id).update_all(claim_token: 'took over', claimed_until: 1.minute.from_now)
      placeholder = chat.messages.create!(role: :assistant, content: '')
      chat.send(:persist_new_message)
    end

    expect(Message.exists?(placeholder.id)).to be(true)
  end

  it 'leaves a blank placeholder alone outside a run that holds the claim' do
    chat, placeholder = killed_stream_chat
    chat = Chat.find(chat.id)

    chat.send(:persist_new_message)

    expect(Message.exists?(placeholder.id)).to be(true)
  end

  it 'runs the unfinished call once the claims expire when the crashed worker had not claimed it' do
    chat, = crashed_chat
    RubyLLM::ActiveRecord::ToolCall.where(tool_call_id: second_call).update_all(claimed_until: nil)
    travel RubyLLM::ActiveRecord::RunClaims::CLAIM_LEASE + 1
    chat = resumed(chat)

    expect(chat.complete.content).to eq('Answered')
    expect(executions).to eq([:lookup])
    expect(result_of(second_call).content).to eq('found')
  end

  it 'answers the unfinished call as unfinished once the user moved on' do
    chat, placeholder = crashed_chat('Hello?')
    travel RubyLLM::ActiveRecord::RunClaims::CLAIM_LEASE + 1
    chat = resumed(chat)

    expect(chat.complete.content).to eq('Answered')
    expect(executions).to be_empty
    expect(sent).to eq([[:user, 'Look twice'], [:assistant, ''], [:tool, 'found', first_call],
                        [:tool, '{"error":"The tool call did not finish."}', second_call], [:user, 'Hello?']])
    expect(result_of(second_call)).to be_nil
    expect(Message.exists?(placeholder.id)).to be(true)
  end
end
