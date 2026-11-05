# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end

  def chat_class_with(*columns)
    ActiveRecord::Base.connection.create_table(:guarded_chats) do |t|
      t.references :ruby_llm_model
      columns.each { |column| t.string column }
    end
    Class.new(ActiveRecord::Base) do
      self.table_name = 'guarded_chats'
      def self.name = 'GuardedChat'

      acts_as_chat messages: :messages, message_class: 'Message', messages_foreign_key: :chat_id
    end
  end

  it 'raises when a column would be hidden by a RubyLLM reader, naming the column and the fix' do
    chat_class = chat_class_with(:temperature, :title)

    expect { chat_class.new }.to raise_error(ArgumentError) { |error|
      expect(error.message).to include('guarded_chats.temperature', 'GuardedChat#temperature',
                                       'rename_column :guarded_chats, :temperature')
      expect(error.message).not_to include('title')
    }
  end

  it 'names every hidden column at once' do
    chat_class = chat_class_with(:cost, :tokens, :context)

    expect { chat_class.column_names }.to raise_error(ArgumentError, /cost.*tokens.*context|cost, tokens, and context/m)
  end

  it 'catches columns hidden by the operations and the Enumerable methods a chat answers' do
    chat_class = chat_class_with(:complete, :count)

    expect { chat_class.new }.to raise_error(ArgumentError, /guarded_chats\.complete, guarded_chats\.count/)
  end

  it 'leaves a table with only its own columns alone' do
    expect(chat_class_with(:title).new).to be_a(ActiveRecord::Base)
    expect(Chat.new).to be_a(Chat)
  end
end
