# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module RubyLLM
  # Generator for RubyLLM Rails models and migrations
  class InstallGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path('install/templates', __dir__)

    desc 'Creates model files for Chat, Message, and ToolCall, and creates migrations for RubyLLM Rails integration'

    def self.next_migration_number(dirname)
      ActiveRecord::Generators::Base.next_migration_number(dirname)
    end

    def migration_version
      "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
    end

    def postgresql?
      ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
    rescue StandardError
      false
    end

    def create_migration_files
      # Create migrations in the correct order with sequential timestamps
      # to ensure proper foreign key references:
      # 1. First create chats (no dependencies)
      # 2. Then create tool_calls (will be referenced by messages)
      # 3. Finally create messages (depends on both chats and tool_calls)

      # Use a fixed timestamp for testing and to ensure they're sequential
      @migration_number = Time.now.utc.strftime('%Y%m%d%H%M%S')
      migration_template 'create_chats_migration.rb.tt', 'db/migrate/create_chats.rb'

      # Increment timestamp for the next migration
      @migration_number = (@migration_number.to_i + 1).to_s
      migration_template 'create_tool_calls_migration.rb.tt', 'db/migrate/create_tool_calls.rb'

      # Increment timestamp again for the final migration
      @migration_number = (@migration_number.to_i + 2).to_s
      migration_template 'create_messages_migration.rb.tt', 'db/migrate/create_messages.rb'
    end

    def create_model_files
      template 'chat_model.rb.tt', 'app/models/chat.rb'
      template 'message_model.rb.tt', 'app/models/message.rb'
      template 'tool_call_model.rb.tt', 'app/models/tool_call.rb'
    end

    def create_initializer
      template 'initializer.rb.tt', 'config/initializers/ruby_llm.rb'
    end

    def show_readme
      readme 'README.md'
    end
  end
end
