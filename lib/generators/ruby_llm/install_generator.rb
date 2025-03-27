# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RubyLLM
  # Generator for RubyLLM Rails models and migrations
  class InstallGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path("install/templates", __dir__)
    
    desc "Creates model files for Chat, Message, and ToolCall, and creates migrations for RubyLLM Rails integration"

    def self.next_migration_number(dirname)
      ActiveRecord::Generators::Base.next_migration_number(dirname)
    end
    
    def migration_version
      "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
    end

    def create_migration_files
      migration_template "create_chats_migration.rb", "db/migrate/create_chats.rb"
      migration_template "create_messages_migration.rb", "db/migrate/create_messages.rb"
      migration_template "create_tool_calls_migration.rb", "db/migrate/create_tool_calls.rb"
    end

    def create_model_files
      template "chat_model.rb", "app/models/chat.rb"
      template "message_model.rb", "app/models/message.rb"
      template "tool_call_model.rb", "app/models/tool_call.rb"
    end

    def create_initializer
      template "initializer.rb", "config/initializers/ruby_llm.rb"
    end

    def show_readme
      readme "README.md"
    end
  end
end