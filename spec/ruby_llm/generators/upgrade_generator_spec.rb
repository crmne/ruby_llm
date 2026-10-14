# frozen_string_literal: true

require 'rails_helper'
require 'generators/ruby_llm/upgrade/upgrade_generator'

RSpec.describe RubyLLM::Generators::UpgradeGenerator, :generator do
  let(:destination) { Dir.mktmpdir('ruby_llm_upgrade') }
  let(:connection) { ActiveRecord::Base.connection }

  after { FileUtils.remove_entry(destination) }

  def migration_class
    described_class.new([], {}, destination_root: destination, shell: Thor::Shell::Basic.new).create_migration_file
    path = Dir.glob(File.join(destination, 'db/migrate/*_upgrade_ruby_llm_to_2_2.rb')).first
    namespace = Module.new
    namespace.module_eval(File.read(path), path)
    namespace.const_get(File.basename(path, '.rb').sub(/\A\d+_/, '').camelize, false)
  end

  it 'adds the run claims and permissions 2.2 needs to a 2.1 schema' do
    upgrade = migration_class

    ActiveRecord::Base.transaction do
      connection.remove_column(:chats, :claim_token)
      connection.remove_column(:chats, :claimed_until)
      connection.remove_column(:ruby_llm_tool_calls, :claimed_until)
      connection.remove_column(:chats, :permissions)
      connection.remove_column(:chats, :permission_grants)

      ActiveRecord::Migration.suppress_messages { upgrade.migrate(:up) }

      expect(connection.column_exists?(:chats, :claim_token, :string)).to be(true)
      expect(connection.column_exists?(:chats, :claimed_until, :datetime)).to be(true)
      expect(connection.column_exists?(:ruby_llm_tool_calls, :claimed_until, :datetime)).to be(true)
      expect(connection.column_exists?(:chats, :permissions, :string)).to be(true)
      expect(connection.column_exists?(:chats, :permission_grants, :json)).to be(true)
      raise ActiveRecord::Rollback
    end
  ensure
    [Chat, RubyLLM::ActiveRecord::ToolCall].each(&:reset_column_information)
  end

  it 'adds the run claims to a mapped chat table' do
    described_class.new(['chat:Conversation'], {}, destination_root: destination, shell: Thor::Shell::Basic.new)
                   .create_migration_file
    migration = File.read(Dir.glob(File.join(destination, 'db/migrate/*_upgrade_ruby_llm_to_2_2.rb')).first)

    expect(migration).to include('add_column :conversations, :claim_token, :string')
    expect(migration).to include('add_column :conversations, :claimed_until, :datetime')
    expect(migration).to include('add_column :conversations, :permissions, :string')
    expect(migration).to include('add_column :conversations, :permission_grants, :json')
  end

  it 'leaves an up-to-date schema alone' do
    expect { ActiveRecord::Migration.suppress_messages { migration_class.migrate(:up) } }.not_to raise_error
  end
end
