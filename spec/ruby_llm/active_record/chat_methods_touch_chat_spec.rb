# frozen_string_literal: true

require 'rails_helper'
require 'active_support/testing/time_helpers'
require_relative '../../support/query_helpers'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'
  include ActiveSupport::Testing::TimeHelpers

  let(:model) { model_for(:openai) }
  let(:touch_chat) { true }
  let(:touches) { [] }

  around do |example|
    create_tables
    example.run
  ensure
    ActiveRecord::Base.connection.drop_table(:touching_messages, if_exists: true)
    ActiveRecord::Base.connection.drop_table(:touched_chats, if_exists: true)
  end

  before do
    touch = touch_chat
    stub_const('TouchingMessage', Class.new(ActiveRecord::Base) do
      self.table_name = 'touching_messages'
      def self.name = 'TouchingMessage'

      acts_as_message chat: :touched_chat, chat_class: 'TouchedChat', touch_chat: touch, broadcasts: false
    end)
    seen = touches
    stub_const('TouchedChat', Class.new(ActiveRecord::Base) do
      self.table_name = 'touched_chats'
      def self.name = 'TouchedChat'

      acts_as_chat messages: :touching_messages, message_class: 'TouchingMessage'
      after_touch { seen << id }
    end)
  end

  def create_tables
    connection = ActiveRecord::Base.connection
    connection.create_table(:touched_chats) do |t|
      t.references :ruby_llm_model
      t.boolean :cancelled, null: false, default: false
      t.string :claim_token
      t.datetime :claimed_until
      t.datetime :last_message_at
      t.timestamps
    end
    connection.create_table(:touching_messages) do |t|
      t.references :touched_chat
      t.string :role
      t.text :content
      t.timestamps
    end
  end

  def job_for(chat)
    TouchedChat.find(chat.id).tap do |job|
      allow(job.to_llm.provider).to receive(:complete)
        .and_return(RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1))
    end
  end

  def chat_writes_per_transaction(job)
    statements = []
    allow(job).to receive(:fenced_by_run_claim).and_wrap_original do |original, &block|
      result = nil
      pattern = /\A(BEGIN|UPDATE "touched_chats")/i
      statements.concat(QueryHelpers.matching(pattern) { result = original.call(&block) })
      result
    end
    yield
    statements.slice_before(/\ABEGIN/i).map { |transaction| transaction.grep(/\AUPDATE/).size }
  end

  def asked_chat
    TouchedChat.create!(model:).tap { |chat| chat.add_message(role: :user, content: 'Hello') }
  end

  # On Postgres, a second write to the claimed chat row in the transaction
  # that renewed the claim rechecks every foreign key the chat holds and
  # locks each row it references, which can deadlock with the application.
  it 'writes the claimed chat row once in the transaction that saves an answer, and touches it after' do
    chat = asked_chat
    job = job_for(chat)
    answered_at = 1.hour.from_now.change(usec: 0)

    writes = chat_writes_per_transaction(job) { travel_to(answered_at) { job.complete } }

    expect(writes).to eq([1, 1])
    expect(chat.reload.updated_at).to eq(answered_at)
    expect(touches).to include(chat.id)
  end

  context 'when the message touches a column of its chat' do
    let(:touch_chat) { :last_message_at }

    it 'touches that column with the timestamp after the answer is saved' do
      chat = asked_chat
      job = job_for(chat)
      answered_at = 1.hour.from_now.change(usec: 0)

      writes = chat_writes_per_transaction(job) { travel_to(answered_at) { job.complete } }

      expect(writes).to eq([1, 1])
      expect(chat.reload.slice(:updated_at, :last_message_at).values).to eq([answered_at, answered_at])
    end
  end
end
