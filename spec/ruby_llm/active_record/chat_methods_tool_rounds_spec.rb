# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:lookup) do
    Class.new(RubyLLM::Tool) do
      def self.name = 'Lookup'

      description 'Looks something up'
      define_method(:execute) { 'found' }
    end
  end

  let(:chat) { Chat.create!(model: model_for(:openai)).tap { |chat| chat.add_message(role: :user, content: 'Go') } }

  def answer = RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)

  def asking
    tool_call = RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name: 'lookup', arguments: {})
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { tool_call.id => tool_call },
                         input_tokens: 1, output_tokens: 1)
  end

  def job_for(chat, rounds:, &reply)
    Chat.find(chat.id).with_tools(lookup).with_tool_options(rounds:).tap do |job|
      allow(job.to_llm.provider).to receive(:complete) { reply.call }
    end
  end

  def stopped_job(rounds: 2)
    job_for(chat, rounds:) { asking }.tap do |job|
      expect { job.complete }.to raise_error(RubyLLM::ToolRoundLimitError)
    end
  end

  def tool_calls
    RubyLLM::ActiveRecord::ToolCall.where(message_id: Chat.find(chat.id).messages.select(:id))
  end

  it 'saves every result of the rounds it ran' do
    stopped_job

    expect(Chat.find(chat.id).messages.order(:id).map(&:role)).to eq(%w[user assistant tool assistant tool])
    expect(tool_calls.map(&:result)).to all(be_present)
  end

  it 'leaves no claim held' do
    stopped_job

    expect(Chat.find(chat.id)).to have_attributes(claim_token: nil, claimed_until: nil)
    expect(Chat.find(chat.id)).not_to be_running
    expect(tool_calls.pluck(:claimed_until)).to all(be_nil)
  end

  it 'does not count as interrupted' do
    stopped_job

    expect(Chat.interrupted.where(id: chat.id)).to be_empty
  end

  it 'keeps the assistant message of the last round, not a blank placeholder' do
    stopped_job

    expect(Chat.find(chat.id).messages.order(:id).last.role).to eq('tool')
  end

  it 'continues from the saved transcript with a fresh count in a later job' do
    stopped_job
    replies = [asking, answer]
    job = job_for(chat, rounds: 2) { replies.shift }

    expect(job.complete.content).to eq('Done')
    expect(Chat.find(chat.id).messages.order(:id).last.content).to eq('Done')
  end

  it 'saves the failed-reply message for the person, as any other stopped reply does' do
    connection = ActiveRecord::Base.connection
    ActiveRecord::Base.transaction do
      connection.add_column(:chats, :reply_error, :string)
      Chat.reset_column_information
      stopped_job
      expect(Chat.find(chat.id).reply_error).to eq('The reply failed. Send your message again.')
      raise ActiveRecord::Rollback
    end
  ensure
    Chat.reset_column_information
  end

  it 'takes the limit from the agent in a job that finds the chat' do
    tool = lookup
    agent_class = Class.new(RubyLLM::Agent) do
      chat_class Chat
      tools tool
      tool_options rounds: 1
    end
    job = agent_class.find(chat.id)
    allow(job.to_llm.provider).to receive(:complete) { asking }

    expect { job.complete }.to raise_error(RubyLLM::ToolRoundLimitError)
    expect(Chat.find(chat.id).messages.order(:id).last.role).to eq('tool')
    expect(Chat.find(chat.id).claim_token).to be_nil
  end
end
