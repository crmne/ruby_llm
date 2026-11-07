# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:anthropic) }
  let(:seen) { [] }

  around do |example|
    ActiveRecord::Base.transaction do
      create_tables
      example.run
      raise ActiveRecord::Rollback
    end
  end

  def create_tables
    connection = ActiveRecord::Base.connection
    connection.create_table(:owned_accounts) { |t| t.string :name }
    connection.create_table(:owned_chats) do |t|
      t.references :ruby_llm_model
      t.references :account
      t.references :owner, polymorphic: true
      t.boolean :cancelled, null: false, default: false
      t.string :claim_token
      t.datetime :claimed_until
      t.timestamps
    end
    connection.create_table(:owned_messages) do |t|
      t.references :owned_chat
      t.string :role
      t.text :content
      t.timestamps
    end
  end

  def define_chat(&)
    stub_const('OwnedAccount', Class.new(ActiveRecord::Base) do
      self.table_name = 'owned_accounts'
      def self.name = 'OwnedAccount'
    end)
    stub_const('OwnedMessage', Class.new(ActiveRecord::Base) do
      self.table_name = 'owned_messages'
      def self.name = 'OwnedMessage'

      acts_as_message chat: :owned_chat, chat_class: 'OwnedChat', broadcasts: false
    end)
    stub_const('OwnedChat', Class.new(ActiveRecord::Base) do
      self.table_name = 'owned_chats'
      def self.name = 'OwnedChat'

      class_exec(&)
    end)
  end

  def define_chat_owned_by_account
    define_chat do
      belongs_to :account, class_name: 'OwnedAccount', optional: true
      acts_as_chat messages: :owned_messages, message_class: 'OwnedMessage', owner: :account
    end
  end

  def answer(content = 'Done')
    RubyLLM::Message.new(role: :assistant, content:, input_tokens: 1, output_tokens: 1)
  end

  def reply_to(chat, *responses)
    allow(chat.to_llm.provider).to receive(:complete) do
      seen << RubyLLM::Accounting::Usage.owner
      responses.many? ? responses.shift : responses.first
    end
    chat
  end

  it 'leaves an owner association of your own to you, as in 2.1' do
    define_chat do
      belongs_to :owner, polymorphic: true, optional: true
      acts_as_chat messages: :owned_messages, message_class: 'OwnedMessage'
    end
    account = OwnedAccount.create!(name: 'Acme')
    other = OwnedAccount.create!(name: 'Other')
    chat = OwnedChat.create!(model:, owner: account)

    reply_to(chat.with_owner(other), answer).ask('Hello')

    expect(chat.owner).to eq(account)
    expect(OwnedChat.find(chat.id).owner).to eq(account)
    expect(chat.ruby_llm_usages.sole.owner).to eq(other)
  end

  it 'attributes every attempt to the record its owner association names, in any process' do
    define_chat_owned_by_account
    account = OwnedAccount.create!(name: 'Acme')
    id = OwnedChat.create!(model:, account:).id
    tool = Class.new(RubyLLM::Tool) do
      description 'Reports who pays'
      define_method(:name) { 'whoami' }
      define_method(:execute) { RubyLLM::Accounting::Usage.owner.name }
    end
    call = RubyLLM::ToolCall.new(id: 'call_1', name: 'whoami', arguments: {})
    tool_call = RubyLLM::Message.new(role: :assistant, content: '', input_tokens: 1, output_tokens: 1,
                                     tool_calls: { call.id => call })
    chat = reply_to(OwnedChat.find(id), tool_call, answer)

    chat.with_tools(tool).ask('Who pays?')

    expect(seen).to eq([account, account])
    expect(chat.owned_messages.find_by(role: 'tool').content).to eq('Acme')
    expect(chat.ruby_llm_usages.map(&:owner)).to eq([account, account])
    expect(chat.to_llm.owner).to eq(account)
  end

  it 'wins over RubyLLM.with_owner, and gives way to with_owner on the record' do
    define_chat_owned_by_account
    account = OwnedAccount.create!(name: 'Acme')
    other = OwnedAccount.create!(name: 'Other')
    chat = reply_to(OwnedChat.create!(model:, account:), answer)

    RubyLLM.with_owner(other) { chat.ask('Hello') }
    chat.with_owner(other).ask('Hello again')

    expect(chat.ruby_llm_usages.map(&:owner)).to eq([account, other])
  end

  it 'follows the association when it changes' do
    define_chat_owned_by_account
    account = OwnedAccount.create!(name: 'Acme')
    other = OwnedAccount.create!(name: 'Other')
    chat = reply_to(OwnedChat.create!(model:, account:), answer)

    chat.ask('Hello')
    chat.update!(account: other)
    chat.ask('Hello again')

    expect(chat.ruby_llm_usages.map(&:owner)).to eq([account, other])
  end

  it 'keeps the files of the Active Storage store for the owner' do
    define_chat_owned_by_account
    account = OwnedAccount.create!(name: 'Acme')
    other = OwnedAccount.create!(name: 'Other')
    chat = OwnedChat.create!(model:, account:).with_file_store

    chat.file_store.write('notes.md', 'For Acme')
    chat.with_owner(other).file_store.write('other.md', 'For Other')

    expect(chat.ruby_llm_chat_files.order(:path).map { |file| [file.path, file.owner] })
      .to eq([['notes.md', account], ['other.md', other]])
    expect(OwnedChat.find(chat.id).with_file_store.file_store.list.map(&:path)).to eq(['notes.md'])
    expect(RubyLLM::ActiveRecord::FileStore.new(chat, owner: other).list.map(&:path)).to eq(['other.md'])
  end

  it 'keeps the files shared when the owner is not a record' do
    define_chat_owned_by_account
    chat = OwnedChat.create!(model:).with_file_store

    chat.with_owner('user-42').file_store.write('notes.md', 'For everyone')

    expect(chat.ruby_llm_chat_files.sole).to have_attributes(owner_type: nil, owner_id: nil)
  end
end
