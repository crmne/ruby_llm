# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::Record do
  include_context 'with configured RubyLLM'

  let(:record_classes) do
    [RubyLLM::ActiveRecord::Model, RubyLLM::ActiveRecord::ToolCall,
     RubyLLM::ActiveRecord::Usage, RubyLLM::ActiveRecord::Batch]
  end

  it 'inherits the default connection without creating another pool' do
    expect(described_class).to be_abstract_class
    expect(described_class.table_name).to be_nil
    expect(record_classes.map(&:connection_pool)).to all(be(ActiveRecord::Base.connection_pool))
    expect(record_classes.map(&:table_name)).to eq(
      %w[ruby_llm_models ruby_llm_tool_calls ruby_llm_usages ruby_llm_batches]
    )
    expect(record_classes).to all(satisfy { |record| !record.abstract_class? })
  end

  context 'with a secondary database' do
    around do |example|
      original_configurations = ActiveRecord::Base.configurations
      original_connection = described_class.connection_specification_name
      original_connection_class = described_class.connection_class?
      ActiveRecord::Base.configurations = {
        Rails.env => {
          primary: ActiveRecord::Base.connection_db_config.configuration_hash,
          llm: { adapter: 'sqlite3', database: ':memory:' }
        }
      }

      example.run
    ensure
      described_class.remove_connection if described_class.connection_specification_name == described_class.name
      described_class.connection_specification_name = original_connection
      described_class.connection_class = original_connection_class
      ActiveRecord::Base.configurations = original_configurations
      record_classes.each(&:reset_column_information)
    end

    it 'connects all four record classes through one secondary pool' do
      described_class.connects_to database: { writing: :llm }

      expect(described_class.connection_db_config.name).to eq('llm')
      expect(described_class.connection_pool).not_to be(ActiveRecord::Base.connection_pool)
      expect(record_classes.map(&:connection_pool)).to all(be(described_class.connection_pool))
    end

    context 'when sharing the application connection' do
      before do
        stub_const('SecondaryRecord', Class.new(ActiveRecord::Base) do
          self.abstract_class = true
        end)
        SecondaryRecord.connects_to database: { writing: :llm }
        described_class.connection_specification_name = SecondaryRecord.connection_specification_name

        schema = ActiveRecord::Schema[7.1].new
        allow(ActiveRecord::Schema[7.1]).to receive(:new).and_return(schema)
        allow(schema).to receive_messages(connection: SecondaryRecord.connection,
                                          connection_pool: SecondaryRecord.connection_pool)
        ActiveRecord::Migration.suppress_messages { load Rails.root.join('db/schema.rb') }

        stub_const('SecondaryChat', Class.new(SecondaryRecord) do
          self.table_name = 'chats'
          acts_as_chat(messages: :messages, message_class: 'SecondaryMessage', messages_foreign_key: :chat_id)
        end)
        stub_const('SecondaryMessage', Class.new(SecondaryRecord) do
          self.table_name = 'messages'
          acts_as_message(chat: :chat, chat_class: 'SecondaryChat', chat_foreign_key: :chat_id)
        end)
      end

      after { SecondaryRecord.remove_connection }

      def persist_conversation
        chat = SecondaryChat.create!(model: model_for(:openai))
        message = chat.add_message(role: :assistant, content: 'Hello')
        message.ruby_llm_tool_calls.create!(tool_call_id: 'call_secondary', name: 'weather', arguments: {})
        message.ruby_llm_usages.create!(chat: chat, operation: 'chat', provider: 'openai',
                                        model: model_for(:openai), status: 'succeeded', input_tokens: 3)
        RubyLLM::ActiveRecord::Batch.create!(provider_batch_id: 'batch_secondary', provider: 'openai',
                                             status: 'pending', chat_type: 'SecondaryChat', chat_ids: [chat.id])
        chat
      end

      it 'persists references together without writing to the default database' do
        original_counts = primary_counts

        chat = persist_conversation.reload

        expect(record_classes.map(&:connection_pool)).to all(be(SecondaryChat.connection_pool))
        expect(chat.model.model_id).to eq(model_for(:openai))
        expect(chat.messages.first.tool_calls.keys).to eq(['call_secondary'])
        expect(chat.tokens.input).to eq(3)
        expect(RubyLLM::ActiveRecord::Batch.last.chats).to eq([chat])
        expect { chat.model.destroy! }.to raise_error(ActiveRecord::InvalidForeignKey)
        expect(primary_counts).to eq(original_counts)
      end

      it 'rolls back application and RubyLLM records in the same transaction' do
        SecondaryChat.transaction do
          persist_conversation
          expect(record_classes.map(&:count)).to all(be_positive)
          raise ActiveRecord::Rollback
        end

        expect([SecondaryChat, SecondaryMessage, *record_classes].map(&:count)).to all(eq(0))
      end

      def primary_counts
        connection = ActiveRecord::Base.connection
        record_classes.to_h do |record|
          table = record.table_name
          [table, connection.select_value("SELECT COUNT(*) FROM #{connection.quote_table_name(table)}")]
        end
      end
    end
  end
end
