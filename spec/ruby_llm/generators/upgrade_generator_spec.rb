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
      connection.remove_column(:ruby_llm_tool_calls, :pending_input)

      ActiveRecord::Migration.suppress_messages { upgrade.migrate(:up) }

      expect(connection.table_exists?(:ruby_llm_mcp_credentials)).to be(true)
      expect(connection.column_exists?(:ruby_llm_tool_calls, :pending_input)).to be(true)
      raise ActiveRecord::Rollback
    end
  end

  it 'leaves an up-to-date schema alone' do
    expect { ActiveRecord::Migration.suppress_messages { migration_class.migrate(:up) } }.not_to raise_error
  end
end
