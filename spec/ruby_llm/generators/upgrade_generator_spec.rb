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

  it 'adds the run claims, provider call IDs, and message phases 2.2 needs to a 2.1 schema' do
    upgrade = migration_class

    ActiveRecord::Base.transaction do
      connection.remove_column(:chats, :claim_token)
      connection.remove_column(:chats, :claimed_until)
      connection.remove_column(:ruby_llm_tool_calls, :claimed_until)
      connection.remove_column(:ruby_llm_tool_calls, :provider_call_id)
      connection.remove_column(:messages, :phase)
      connection.remove_column(:ruby_llm_tool_calls, :namespace)

      ActiveRecord::Migration.suppress_messages { upgrade.migrate(:up) }

      expect(connection.column_exists?(:chats, :claim_token, :string)).to be(true)
      expect(connection.column_exists?(:chats, :claimed_until, :datetime)).to be(true)
      expect(connection.column_exists?(:ruby_llm_tool_calls, :claimed_until, :datetime)).to be(true)
      expect(connection.column_exists?(:ruby_llm_tool_calls, :provider_call_id, :string)).to be(true)
      expect(connection.column_exists?(:messages, :phase, :string)).to be(true)
      expect(connection.column_exists?(:ruby_llm_tool_calls, :namespace, :string)).to be(true)
      raise ActiveRecord::Rollback
    end
  ensure
    [Chat, Message, RubyLLM::ActiveRecord::ToolCall].each(&:reset_column_information)
  end

  it 'removes what it added when rolled back' do
    upgrade = migration_class

    ActiveRecord::Base.transaction do
      ActiveRecord::Migration.suppress_messages { upgrade.migrate(:down) }

      expect(connection.column_exists?(:chats, :claim_token)).to be(false)
      expect(connection.column_exists?(:chats, :claimed_until)).to be(false)
      expect(connection.column_exists?(:ruby_llm_tool_calls, :claimed_until)).to be(false)
      expect(connection.column_exists?(:ruby_llm_tool_calls, :provider_call_id)).to be(false)
      expect(connection.column_exists?(:messages, :phase)).to be(false)
      expect(connection.column_exists?(:ruby_llm_tool_calls, :namespace)).to be(false)
      expect(connection.table_exists?(:ruby_llm_queued_messages)).to be(false)
      expect(connection.table_exists?(:ruby_llm_chat_files)).to be(false)
      raise ActiveRecord::Rollback
    end
  ensure
    [Chat, Message, RubyLLM::ActiveRecord::ToolCall, RubyLLM::ActiveRecord::QueuedMessage].each(&:reset_column_information)
  end

  it 'creates the queued messages table 2.2 needs' do
    upgrade = migration_class

    ActiveRecord::Base.transaction do
      connection.drop_table(:ruby_llm_queued_messages)

      ActiveRecord::Migration.suppress_messages { upgrade.migrate(:up) }

      %w[chat_type chat_id owner_type owner_id content steer created_at updated_at].each do |column|
        expect(connection.column_exists?(:ruby_llm_queued_messages, column)).to be(true)
      end
      expect(connection.index_exists?(:ruby_llm_queued_messages, %i[chat_type chat_id])).to be(true)
      raise ActiveRecord::Rollback
    end
  ensure
    RubyLLM::ActiveRecord::QueuedMessage.reset_column_information
  end

  it 'creates the chat files table 2.2 needs' do
    upgrade = migration_class

    ActiveRecord::Base.transaction do
      connection.drop_table(:ruby_llm_chat_files)

      ActiveRecord::Migration.suppress_messages { upgrade.migrate(:up) }

      %w[chat_type chat_id owner_type owner_id path content_type byte_size digest text].each do |column|
        expect(connection.column_exists?(:ruby_llm_chat_files, column)).to be(true)
      end
      expect(connection.index_exists?(:ruby_llm_chat_files, %i[chat_type chat_id path])).to be(true)
      raise ActiveRecord::Rollback
    end
  ensure
    RubyLLM::ActiveRecord::ChatFile.reset_column_information
  end

  it 'adds the workflow columns 2.2 records on usage rows' do
    upgrade = migration_class
    columns = %i[workflow_id workflow_name workflow_step_id workflow_step_name]

    ActiveRecord::Base.transaction do
      connection.remove_index(:ruby_llm_usages, :workflow_id)
      columns.each { |column| connection.remove_column(:ruby_llm_usages, column) }

      ActiveRecord::Migration.suppress_messages { upgrade.migrate(:up) }

      columns.each { |column| expect(connection.column_exists?(:ruby_llm_usages, column, :string)).to be(true) }
      expect(connection.index_exists?(:ruby_llm_usages, :workflow_id)).to be(true)

      ActiveRecord::Migration.suppress_messages { upgrade.migrate(:down) }

      columns.each { |column| expect(connection.column_exists?(:ruby_llm_usages, column)).to be(false) }
      raise ActiveRecord::Rollback
    end
  ensure
    RubyLLM::ActiveRecord::Usage.reset_column_information
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

  it 'renames the earlier provider ID column without changing saved call IDs' do
    invocation_id = SecureRandom.uuid
    chat = Chat.create!(model: model_for(:openai))
    message = chat.messages.create!(role: :assistant, content: '')
    call = message.ruby_llm_tool_calls.create!(tool_call_id: invocation_id,
                                               provider_call_id: 'call_1', name: 'lookup')

    ActiveRecord::Base.transaction do
      connection.rename_column(:ruby_llm_tool_calls, :provider_call_id, :provider_id)
      ActiveRecord::Migration.suppress_messages { migration_class.migrate(:up) }

      expect(connection.column_exists?(:ruby_llm_tool_calls, :provider_id)).to be(false)
      expect(call.reload.provider_call_id).to eq('call_1')
      expect(call.to_llm.id).to eq(invocation_id)
      raise ActiveRecord::Rollback
    end
  ensure
    RubyLLM::ActiveRecord::ToolCall.reset_column_information
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

  it 'keeps the broadcasting a 2.1 chat UI job still calls' do
    model = <<~'RUBY'
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
    files = {
      'app/models/message.rb' => model,
      'app/jobs/chat_response_job.rb' => "message.broadcast_append_chunk(chunk.content)\n",
      'config/initializers/ruby_llm.rb' => "RubyLLM.configure do |config|\nend\n"
    }
    files.each do |path, body|
      FileUtils.mkdir_p(File.dirname(File.join(destination, path)))
      File.write(File.join(destination, path), body)
    end
    shell = Thor::Shell::Basic.new
    allow(shell).to receive(:say)

    described_class.new([], {}, destination_root: destination, shell: shell)
                   .remove_generated_message_code_from_message_model

    expect(File.read(File.join(destination, 'app/models/message.rb'))).to eq(model)
    expect(File.read(File.join(destination, 'config/initializers/ruby_llm.rb'))).not_to include('broadcast_messages')
    expect(shell).to have_received(:say).with(/ruby_llm:chat_ui/, anything)
  end

  it 'keeps the broadcasting a 2.1 chat UI page still subscribes to' do
    path = File.join(destination, 'app/models/message.rb')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, <<~'RUBY')
      class Message < ApplicationRecord
        acts_as_message

        broadcasts_to ->(message) { "chat_#{message.chat_id}" }, inserts_by: :append

        def broadcast_append_chunk(content)
          broadcast_append_to "chat_#{chat_id}",
            target: "message_#{id}_content",
            content: ERB::Util.html_escape(content.to_s)
        end
      end
    RUBY
    view = File.join(destination, 'app/views/chats/show.html.erb')
    FileUtils.mkdir_p(File.dirname(view))
    File.write(view, %(<%= turbo_stream_from "chat_\#{@chat.id}" %>\n))

    described_class.new([], {}, destination_root: destination, shell: Thor::Shell::Basic.new)
                   .remove_generated_message_code_from_message_model

    expect(File.read(path)).to include('def broadcast_append_chunk(content)')
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
