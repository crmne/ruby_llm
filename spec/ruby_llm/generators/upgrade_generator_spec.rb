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

  it 'adds the run claims and provider call IDs 2.2 needs to a 2.1 schema' do
    upgrade = migration_class

    ActiveRecord::Base.transaction do
      connection.remove_column(:chats, :claim_token)
      connection.remove_column(:chats, :claimed_until)
      connection.remove_column(:ruby_llm_tool_calls, :claimed_until)
      connection.remove_column(:ruby_llm_tool_calls, :provider_id)

      ActiveRecord::Migration.suppress_messages { upgrade.migrate(:up) }

      expect(connection.column_exists?(:chats, :claim_token, :string)).to be(true)
      expect(connection.column_exists?(:chats, :claimed_until, :datetime)).to be(true)
      expect(connection.column_exists?(:ruby_llm_tool_calls, :claimed_until, :datetime)).to be(true)
      expect(connection.column_exists?(:ruby_llm_tool_calls, :provider_id, :string)).to be(true)
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

  it 'removes the broadcasting and attachments 2.1 wrote into the message model' do
    path = File.join(destination, 'app/models/message.rb')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, <<~'RUBY')
      class Message < ApplicationRecord
        acts_as_message
        has_many_attached :attachments

        broadcasts_to ->(message) { "chat_#{message.chat_id}" }, inserts_by: :append

        def broadcast_append_chunk(content)
          broadcast_append_to "chat_#{chat_id}",
            target: "message_#{id}_content",
            content: ERB::Util.html_escape(content.to_s)
        end
      end
    RUBY

    initializer = File.join(destination, 'config/initializers/ruby_llm.rb')
    FileUtils.mkdir_p(File.dirname(initializer))
    File.write(initializer, "RubyLLM.configure do |config|\n  config.openai_api_key = ENV['OPENAI_API_KEY']\nend\n")

    described_class.new([], {}, destination_root: destination, shell: Thor::Shell::Basic.new)
                   .remove_generated_message_code_from_message_model

    expect(File.read(path)).to eq("class Message < ApplicationRecord\n  acts_as_message\nend\n")
    expect(File.read(initializer)).to end_with("  config.broadcast_messages = true\nend\n")
  end

  it 'leaves broadcasting off for a message model without the generated block' do
    path = File.join(destination, 'app/models/message.rb')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "class Message < ApplicationRecord\n  acts_as_message\nend\n")
    initializer = File.join(destination, 'config/initializers/ruby_llm.rb')
    FileUtils.mkdir_p(File.dirname(initializer))
    File.write(initializer, "RubyLLM.configure do |config|\nend\n")

    described_class.new([], {}, destination_root: destination, shell: Thor::Shell::Basic.new)
                   .remove_generated_message_code_from_message_model

    expect(File.read(initializer)).not_to include('broadcast_messages')
  end

  it 'installs Active Storage when its tables are missing' do
    generator = described_class.new([], {}, destination_root: destination, shell: Thor::Shell::Basic.new)
    allow(generator).to receive(:table_exists?).with('active_storage_blobs').and_return(false)
    allow(generator).to receive(:rails_command)

    generator.install_active_storage

    expect(generator).to have_received(:rails_command).with('active_storage:install')
  end

  it 'leaves an existing ApplicationAgent alone' do
    path = File.join(destination, 'app/agents/application_agent.rb')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "class ApplicationAgent < RubyLLM::Agent\n  chat_model Chat\n  model 'gpt-5.6-luna'\nend\n")

    described_class.new([], {}, destination_root: destination, shell: Thor::Shell::Basic.new).create_app_directories

    expect(File.read(path)).to include("model 'gpt-5.6-luna'")
  end
end
