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

  it 'adds the run claims 2.2 needs to a 2.1 schema' do
    upgrade = migration_class

    ActiveRecord::Base.transaction do
      connection.remove_column(:chats, :claim_token)
      connection.remove_column(:chats, :claimed_until)
      connection.remove_column(:ruby_llm_tool_calls, :claimed_until)

      ActiveRecord::Migration.suppress_messages { upgrade.migrate(:up) }

      expect(connection.column_exists?(:chats, :claim_token, :string)).to be(true)
      expect(connection.column_exists?(:chats, :claimed_until, :datetime)).to be(true)
      expect(connection.column_exists?(:ruby_llm_tool_calls, :claimed_until, :datetime)).to be(true)
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
  end

  it 'leaves an up-to-date schema alone' do
    expect { ActiveRecord::Migration.suppress_messages { migration_class.migrate(:up) } }.not_to raise_error
  end

  it 'creates the app directories the application is missing, keeping existing ones' do
    FileUtils.mkdir_p(File.join(destination, 'app/skills/invoices'))
    generator = described_class.new([], {}, destination_root: destination, shell: Thor::Shell::Basic.new)

    generator.create_app_directories

    %w[agents tools schemas prompts skills sandboxes mcp evals judges].each do |name|
      expect(File.directory?(File.join(destination, 'app', name))).to be(true)
    end
    expect(File.directory?(File.join(destination, 'app/skills/invoices'))).to be(true)
  end

  it 'adds an ApplicationAgent for the mapped chat model' do
    described_class.new(['chat:Conversation'], {}, destination_root: destination, shell: Thor::Shell::Basic.new)
                   .create_app_directories

    expect(File.read(File.join(destination, 'app/agents/application_agent.rb')))
      .to eq("class ApplicationAgent < RubyLLM::Agent\n  chat_model Conversation\nend\n")
  end

  it 'leaves an existing ApplicationAgent alone' do
    path = File.join(destination, 'app/agents/application_agent.rb')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "class ApplicationAgent < RubyLLM::Agent\n  chat_model Chat\n  model 'gpt-5.6-luna'\nend\n")

    described_class.new([], {}, destination_root: destination, shell: Thor::Shell::Basic.new).create_app_directories

    expect(File.read(path)).to include("model 'gpt-5.6-luna'")
  end
end
