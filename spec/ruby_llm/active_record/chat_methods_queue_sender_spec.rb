# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:openai) }
  let(:sender) { Chat.create!(model:) }
  let(:sender_association) { { polymorphic: true } }

  around do |example|
    ActiveRecord::Base.transaction do
      create_tables
      example.run
      raise ActiveRecord::Rollback
    end
  end

  before do
    options = sender_association
    stub_const('SentMessage', Class.new(ActiveRecord::Base) do
      self.table_name = 'sent_messages'
      def self.name = 'SentMessage'

      acts_as_message chat: :sent_chat, chat_class: 'SentChat', broadcasts: false
      belongs_to :sender, optional: true, **options
    end)
    stub_const('SentChat', Class.new(ActiveRecord::Base) do
      self.table_name = 'sent_chats'
      def self.name = 'SentChat'

      acts_as_chat messages: :sent_messages, message_class: 'SentMessage'
    end)
  end

  def create_tables
    connection = ActiveRecord::Base.connection
    connection.create_table(:sent_chats) do |t|
      t.references :ruby_llm_model
      t.boolean :cancelled, null: false, default: false
      t.string :claim_token
      t.datetime :claimed_until
      t.timestamps
    end
    connection.create_table(:sent_messages) do |t|
      t.references :sent_chat
      t.references :sender, polymorphic: true
      t.string :role
      t.text :content
      t.timestamps
    end
    connection.create_table(:sent_people) { |t| t.string :type }
  end

  def job_for(chat)
    SentChat.find(chat.id).tap do |job|
      allow(job.to_llm.provider).to receive(:complete)
        .and_return(RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1))
    end
  end

  it 'saves the message a queued one becomes with its sender, when the message model has a sender' do
    chat = SentChat.create!(model:)
    chat.queue('Use the EU file', sender:)
    chat.queue('Then email it')

    job_for(chat).complete

    expect(chat.sent_messages.where(role: 'user').map { |message| [message.content, message.sender] })
      .to eq([['Use the EU file', sender], ['Then email it', nil]])
  end

  context 'when the sender association takes one class' do
    let(:sender_association) { { class_name: 'SentChat' } }

    it 'saves a sender of that class, and joins a message from another without its sender' do
      chat = SentChat.create!(model:)
      colleague = SentChat.create!(model:)
      chat.queue('From a colleague', sender: colleague)
      chat.queue('From elsewhere', sender:)

      job_for(chat).complete

      expect(chat.sent_messages.where(role: 'user').map { |message| [message.content, message.sender] })
        .to eq([['From a colleague', colleague], ['From elsewhere', nil]])
      expect(chat.queued_messages).to be_empty
    end
  end

  it 'lets around_join set another sender' do
    chat = SentChat.create!(model:)
    other = Chat.create!(model:)
    chat.queue('Hello', sender:)
    job = job_for(chat)
    job.around_join { |_queued, join| join.call(sender: other) }

    job.complete

    expect(chat.sent_messages.find_by(role: 'user').sender).to eq(other)
  end

  context 'when the queued sender class no longer exists' do
    let(:chat) { SentChat.create!(model:) }

    before do
      chat.queue('Hello', sender:)
      chat.ruby_llm_queued_messages.update_all(sender_type: 'RenamedSender')
    end

    it 'joins the message without its sender' do
      job_for(chat).complete

      expect(chat.sent_messages.where(role: 'user').map { |message| [message.content, message.sender] })
        .to eq([['Hello', nil]])
      expect(chat.queued_messages).to be_empty
    end

    it 'lets around_join set another sender' do
      other = Chat.create!(model:)
      job = job_for(chat)
      job.around_join { |_queued, join| join.call(sender: other) }

      job.complete

      expect(chat.sent_messages.find_by(role: 'user').sender).to eq(other)
    end
  end

  it 'joins a message without its sender once the sender record names a subclass that no longer exists' do
    stub_const('SentPerson', Class.new(ActiveRecord::Base) do
      self.table_name = 'sent_people'
      def self.name = 'SentPerson'
    end)
    chat = SentChat.create!(model:)
    person = SentPerson.create!
    chat.queue('Hello', sender: person)
    SentPerson.where(id: person.id).update_all(type: 'RenamedPerson')

    job_for(chat).complete

    expect(chat.sent_messages.where(role: 'user').map { |message| [message.content, message.sender] })
      .to eq([['Hello', nil]])
    expect(chat.queued_messages).to be_empty
  end
end
