# frozen_string_literal: true

require 'rails_helper'
require 'generators/ruby_llm/upgrade/upgrade_generator'

RSpec.describe RubyLLM::Generators::UpgradeGenerator, :generator do
  let(:destination) { Dir.mktmpdir('ruby_llm_upgrade') }
  let(:connection) { ActiveRecord::Base.connection }

  after { FileUtils.remove_entry(destination) }

  def migration_class
    described_class.new([], {}, destination_root: destination, shell: Thor::Shell::Basic.new).create_migration_file
    path = Dir.glob(File.join(destination, 'db/migrate/*_upgrade_ruby_llm_to_2_1.rb')).first
    namespace = Module.new
    namespace.module_eval(File.read(path), path)
    namespace.const_get(File.basename(path, '.rb').sub(/\A\d+_/, '').camelize, false)
  end

  it 'adds what 2.1 needs to a 2.0 schema' do
    upgrade = migration_class

    ActiveRecord::Base.transaction do
      connection.drop_table(:ruby_llm_mcp_credentials)
      connection.remove_column(:ruby_llm_tool_calls, :mcp_state)
      connection.remove_column(:ruby_llm_tool_calls, :mcp_result)
      connection.remove_column(:ruby_llm_usages, :server_tool_use)
      connection.drop_table(:ruby_llm_provider_files)

      ActiveRecord::Migration.suppress_messages { upgrade.migrate(:up) }

      expect(connection.table_exists?(:ruby_llm_mcp_credentials)).to be(true)
      expect(connection.column_exists?(:ruby_llm_tool_calls, :mcp_state)).to be(true)
      expect(connection.column_exists?(:ruby_llm_tool_calls, :mcp_result)).to be(true)
      expect(connection.column_exists?(:ruby_llm_usages, :server_tool_use)).to be(true)
      expect(connection.index_exists?(:ruby_llm_provider_files, %i[blob_key provider account], unique: true))
        .to be(true)
      raise ActiveRecord::Rollback
    end
  end

  it 'renames the pending_input column an earlier 2.1 upgrade added' do
    upgrade = migration_class

    ActiveRecord::Base.transaction do
      connection.rename_column(:ruby_llm_tool_calls, :mcp_state, :pending_input)

      ActiveRecord::Migration.suppress_messages { upgrade.migrate(:up) }

      expect(connection.column_exists?(:ruby_llm_tool_calls, :mcp_state)).to be(true)
      expect(connection.column_exists?(:ruby_llm_tool_calls, :pending_input)).to be(false)
      raise ActiveRecord::Rollback
    end
  end

  it 'frees the usage ledger from chats and adds its owner on an app that ran the earlier 2.1 upgrade' do
    upgrade = migration_class

    ActiveRecord::Base.transaction do
      connection.remove_reference(:ruby_llm_usages, :owner, polymorphic: true, index: true)
      connection.change_column_null(:ruby_llm_usages, :chat_type, false, 'Chat')
      connection.change_column_null(:ruby_llm_usages, :chat_id, false, 0)
      expect(connection.columns(:ruby_llm_usages).find { |column| column.name == 'chat_id' }.null).to be(false)

      ActiveRecord::Migration.suppress_messages { upgrade.migrate(:up) }

      columns = connection.columns(:ruby_llm_usages).index_by(&:name)
      expect(columns.values_at('chat_type', 'chat_id').map(&:null)).to eq([true, true])
      expect(columns).to include('owner_type', 'owner_id')
      expect(connection.index_exists?(:ruby_llm_usages, %i[owner_type owner_id])).to be(true)
      raise ActiveRecord::Rollback
    end
  end

  it 'lets the operation constraint of a 2.0 schema accept every operation' do
    upgrade = migration_class
    earlier_operations = "operation IN ('chat', 'embedding', 'moderation', 'image', 'speech', 'transcription', " \
                         "'ocr', 'rerank')"

    ActiveRecord::Base.transaction do
      connection.delete('DELETE FROM ruby_llm_usages')
      connection.add_check_constraint(:ruby_llm_usages, earlier_operations)

      ActiveRecord::Migration.suppress_messages { upgrade.migrate(:up) }

      expressions = connection.check_constraints(:ruby_llm_usages).map(&:expression)
      expect(expressions.size).to eq(1)
      expect(expressions.first).to include(*RubyLLM::Accounting::Usage::Entry::OPERATIONS.map { |op| "'#{op}'" })
      raise ActiveRecord::Rollback
    end
  end

  it 'leaves an up-to-date schema alone' do
    expect { ActiveRecord::Migration.suppress_messages { migration_class.migrate(:up) } }.not_to raise_error
  end
end
