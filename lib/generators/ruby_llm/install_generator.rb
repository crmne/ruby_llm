# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module RubyLLM
  # Generator for RubyLLM Rails models and migrations
  class InstallGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    namespace 'ruby_llm:install'

    source_root File.expand_path('install/templates', __dir__)

    class_option :chat_model_name, type: :string, default: 'Chat',
                                   desc: 'Name of the Chat model class'
    class_option :message_model_name, type: :string, default: 'Message',
                                      desc: 'Name of the Message model class'
    class_option :tool_call_model_name, type: :string, default: 'ToolCall',
                                        desc: 'Name of the ToolCall model class'
    class_option :model_model_name, type: :string, default: 'Model',
                                    desc: 'Name of the Model model class (for model registry)'
    class_option :skip_model_registry, type: :boolean, default: false,
                                       desc: 'Skip creating Model registry (uses string fields instead)'
    class_option :skip_active_storage, type: :boolean, default: false,
                                       desc: 'Skip ActiveStorage installation and attachment setup'

    desc 'Creates models and migrations for RubyLLM Rails integration with ActiveStorage for file attachments'

    def self.next_migration_number(dirname)
      ::ActiveRecord::Generators::Base.next_migration_number(dirname)
    end

    def migration_version
      "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
    end

    def postgresql?
      ::ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
    rescue StandardError
      false
    end

    def acts_as_chat_declaration
      acts_as_chat_params = []
      if options[:message_model_name] != 'Message'
        acts_as_chat_params << "message_class: \"#{options[:message_model_name]}\""
      end
      if options[:tool_call_model_name] != 'ToolCall'
        acts_as_chat_params << "tool_call_class: \"#{options[:tool_call_model_name]}\""
      end
      if acts_as_chat_params.any?
        "acts_as_chat #{acts_as_chat_params.join(', ')}"
      else
        'acts_as_chat'
      end
    end

    def acts_as_message_declaration
      acts_as_message_params = []
      acts_as_message_params << "chat_class: \"#{options[:chat_model_name]}\"" if options[:chat_model_name] != 'Chat'
      if options[:tool_call_model_name] != 'ToolCall'
        acts_as_message_params << "tool_call_class: \"#{options[:tool_call_model_name]}\""
      end
      if acts_as_message_params.any?
        "acts_as_message #{acts_as_message_params.join(', ')}"
      else
        'acts_as_message'
      end
    end

    def acts_as_tool_call_declaration
      acts_as_tool_call_params = []
      if options[:message_model_name] != 'Message'
        acts_as_tool_call_params << "message_class: \"#{options[:message_model_name]}\""
      end
      if acts_as_tool_call_params.any?
        "acts_as_tool_call #{acts_as_tool_call_params.join(', ')}"
      else
        'acts_as_tool_call'
      end
    end

    def acts_as_model_declaration
      'acts_as_model'
    end

    def skip_model_registry?
      options[:skip_model_registry]
    end

    def create_migration_files
      # Create migrations with timestamps to ensure proper order
      # First create chats table
      template_file = skip_model_registry? ? 'create_chats_legacy_migration.rb.tt' : 'create_chats_migration.rb.tt'
      migration_template template_file,
                         "db/migrate/create_#{options[:chat_model_name].tableize}.rb"

      # Then create messages table (must come before tool_calls due to foreign key)
      sleep 1 # Ensure different timestamp
      template_file = if skip_model_registry?
                        'create_messages_legacy_migration.rb.tt'
                      else
                        'create_messages_migration.rb.tt'
                      end
      migration_template template_file,
                         "db/migrate/create_#{options[:message_model_name].tableize}.rb"

      # Then create tool_calls table (references messages)
      sleep 1 # Ensure different timestamp
      migration_template 'create_tool_calls_migration.rb.tt',
                         "db/migrate/create_#{options[:tool_call_model_name].tableize}.rb"

      # Create models table unless using legacy or skipping
      return if skip_model_registry?

      sleep 1 # Ensure different timestamp
      migration_template 'create_models_migration.rb.tt',
                         "db/migrate/create_#{options[:model_model_name].tableize}.rb"
    end

    def create_model_files
      template 'chat_model.rb.tt', "app/models/#{options[:chat_model_name].underscore}.rb"
      template 'message_model.rb.tt', "app/models/#{options[:message_model_name].underscore}.rb"
      template 'tool_call_model.rb.tt', "app/models/#{options[:tool_call_model_name].underscore}.rb"

      # Only create Model class if not using legacy
      return if skip_model_registry?

      template 'model_model.rb.tt', "app/models/#{options[:model_model_name].underscore}.rb"
    end

    def create_initializer
      template 'initializer.rb.tt', 'config/initializers/ruby_llm.rb'
    end

    def install_active_storage
      return if options[:skip_active_storage]

      say '  Installing ActiveStorage for file attachments...', :cyan
      rails_command 'active_storage:install'
    end

    def show_install_info
      say "\n  ✅ RubyLLM installed!", :green

      say '  ✅ ActiveStorage configured for file attachments support', :green unless options[:skip_active_storage]

      say "\n  Next steps:", :yellow
      say '     1. Run: rails db:migrate'
      say '     2. Set your API keys in config/initializers/ruby_llm.rb'

      if skip_model_registry?
        say "     3. Start chatting: #{options[:chat_model_name]}.create!(model_id: 'gpt-4.1-nano').ask('Hello!')"

        say "\n  Note: Using string-based model fields", :yellow
        say '     For rich model metadata, consider adding the model registry:'
        say '     rails generate ruby_llm:migrate_model_fields'
      else
        say "     3. Start chatting: #{options[:chat_model_name]}.create!(model: 'gpt-4.1-nano').ask('Hello!')"

        say "\n  🚀 Model registry is database-backed!", :cyan
        say '     Models automatically load from the database'
        say '     Pass model names as strings - RubyLLM handles the rest!'
      end
      say "     Specify provider when needed: Chat.create!(model: 'gemini-2.5-flash', provider: 'vertexai')"

      if options[:skip_active_storage]
        say "\n  📎 Note: ActiveStorage was skipped", :yellow
        say '     File attachments won\'t work without ActiveStorage.'
        say '     To enable later:'
        say '       1. Run: rails active_storage:install && rails db:migrate'
        say "       2. Add to your #{options[:message_model_name]} model: has_many_attached :attachments"
      end

      say "\n  📚 Documentation: https://rubyllm.com", :cyan

      say "\n  ❤️  Love RubyLLM?", :magenta
      say '     • ⭐ Star on GitHub: https://github.com/crmne/ruby_llm'
      say '     • 🐦 Follow for updates: https://x.com/paolino'
      say "\n"
    end
  end
end
