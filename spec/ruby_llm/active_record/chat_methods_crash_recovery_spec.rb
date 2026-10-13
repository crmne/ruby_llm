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
  # chat and on the unfinished call outlive it.
  def crashed_chat(*later_questions)
    chat = Chat.create!(model: model_for(:openai))
    chat.add_message(role: :user, content: 'Look twice')
    calls = [first_call, second_call].to_h { |id| [id, RubyLLM::ToolCall.new(id:, name: 'lookup', arguments: {})] }
    chat.add_message(role: :assistant, content: '', tool_calls: calls)
    chat.add_message(role: :tool, content: 'found', tool_call_id: first_call)
    placeholder = chat.messages.create!(role: :assistant, content: '')
    later_questions.each { |question| chat.messages.create!(role: :user, content: question) }
    claimed_until = RubyLLM.config.max_run_time.seconds.from_now
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

  it 'runs the unfinished call again once the claims expire' do
    chat, placeholder = crashed_chat
    travel RubyLLM.config.max_run_time + 1
    chat = resumed(chat)

    expect(chat.complete.content).to eq('Answered')
    expect(executions).to eq([:lookup])
    expect(sent).to eq([[:user, 'Look twice'], [:assistant, ''], [:tool, 'found', first_call],
                        [:tool, 'found', second_call]])
    expect(result_of(second_call).content).to eq('found')
    expect(Message.exists?(placeholder.id)).to be(true)
  end

  it 'answers the unfinished call as unfinished once the user moved on' do
    chat, placeholder = crashed_chat('Hello?')
    travel RubyLLM.config.max_run_time + 1
    chat = resumed(chat)

    expect(chat.complete.content).to eq('Answered')
    expect(executions).to be_empty
    expect(sent).to eq([[:user, 'Look twice'], [:assistant, ''], [:tool, 'found', first_call],
                        [:tool, '{"error":"The tool call did not finish."}', second_call], [:user, 'Hello?']])
    expect(result_of(second_call)).to be_nil
    expect(Message.exists?(placeholder.id)).to be(true)
  end
end
