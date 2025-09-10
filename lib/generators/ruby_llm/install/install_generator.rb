# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module RubyLLM
  # Generator for RubyLLM Rails models and migrations
  class InstallGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    namespace 'ruby_llm:install'

    source_root File.expand_path('templates', __dir__)

    argument :model_mappings, type: :array, default: [], banner: 'chat:ChatName message:MessageName ...'

    class_option :skip_active_storage, type: :boolean, default: false,
                                       desc: 'Skip ActiveStorage installation and attachment setup'

    desc 'Creates models and migrations for RubyLLM Rails integration\n' \
         'Usage: rails g ruby_llm:install [chat:ChatName] [message:MessageName] ...'

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

    def parse_model_mappings
      @model_names = {
        chat: 'Chat',
        message: 'Message',
        tool_call: 'ToolCall',
        model: 'Model'
      }

      model_mappings.each do |mapping|
        if mapping.include?(':')
          key, value = mapping.split(':', 2)
          @model_names[key.to_sym] = value.classify
        end
      end

      @model_names
    end

    %i[chat message tool_call model].each do |type|
      define_method("#{type}_model_name") do
        @model_names ||= parse_model_mappings
        @model_names[type]
      end

      define_method("#{type}_table_name") do
        table_name_for(send("#{type}_model_name"))
      end
    end

    def acts_as_chat_declaration
      acts_as_chat_params = []
      messages_assoc = message_model_name.tableize.to_sym
      model_assoc = model_model_name.underscore.to_sym

      if messages_assoc != :messages
        acts_as_chat_params << "messages: :#{messages_assoc}"
        if message_model_name != messages_assoc.to_s.classify
          acts_as_chat_params << "message_class: '#{message_model_name}'"
        end
      end

      if model_assoc != :model
        acts_as_chat_params << "model: :#{model_assoc}"
        acts_as_chat_params << "model_class: '#{model_model_name}'" if model_model_name != model_assoc.to_s.classify
      end

      if acts_as_chat_params.any?
        "acts_as_chat #{acts_as_chat_params.join(', ')}"
      else
        'acts_as_chat'
      end
    end

    def acts_as_message_declaration
      params = []

      add_message_association_params(params, :chat, chat_model_name)
      add_message_association_params(params, :tool_calls, tool_call_model_name, tableize: true)
      add_message_association_params(params, :model, model_model_name)

      params.any? ? "acts_as_message #{params.join(', ')}" : 'acts_as_message'
    end

    private

    def add_message_association_params(params, default_assoc, model_name, tableize: false)
      assoc = tableize ? model_name.tableize.to_sym : model_name.underscore.to_sym

      return if assoc == default_assoc

      params << "#{default_assoc}: :#{assoc}"
      expected_class = assoc.to_s.classify
      params << "#{default_assoc.to_s.singularize}_class: '#{model_name}'" if model_name != expected_class
    end

    public

    def acts_as_tool_call_declaration
      acts_as_tool_call_params = []
      message_assoc = message_model_name.underscore.to_sym

      if message_assoc != :message
        acts_as_tool_call_params << "message: :#{message_assoc}"
        if message_model_name != message_assoc.to_s.classify
          acts_as_tool_call_params << "message_class: '#{message_model_name}'"
        end
      end

      if acts_as_tool_call_params.any?
        "acts_as_tool_call #{acts_as_tool_call_params.join(', ')}"
      else
        'acts_as_tool_call'
      end
    end

    def acts_as_model_declaration
      acts_as_model_params = []
      chats_assoc = chat_model_name.tableize.to_sym

      if chats_assoc != :chats
        acts_as_model_params << "chats: :#{chats_assoc}"
        acts_as_model_params << "chat_class: '#{chat_model_name}'" if chat_model_name != chats_assoc.to_s.classify
      end

      if acts_as_model_params.any?
        "acts_as_model #{acts_as_model_params.join(', ')}"
      else
        'acts_as_model'
      end
    end

    def create_migration_files
      # Create migrations with timestamps to ensure proper order
      # First create chats table
      migration_template 'create_chats_migration.rb.tt',
                         "db/migrate/create_#{chat_table_name}.rb"

      # Then create messages table (must come before tool_calls due to foreign key)
      sleep 1 # Ensure different timestamp
      migration_template 'create_messages_migration.rb.tt',
                         "db/migrate/create_#{message_table_name}.rb"

      # Then create tool_calls table (references messages)
      sleep 1 # Ensure different timestamp
      migration_template 'create_tool_calls_migration.rb.tt',
                         "db/migrate/create_#{tool_call_table_name}.rb"

      # Create models table
      sleep 1 # Ensure different timestamp
      migration_template 'create_models_migration.rb.tt',
                         "db/migrate/create_#{model_table_name}.rb"
    end

    def create_model_files
      template 'chat_model.rb.tt', "app/models/#{chat_model_name.underscore}.rb"
      template 'message_model.rb.tt', "app/models/#{message_model_name.underscore}.rb"
      template 'tool_call_model.rb.tt', "app/models/#{tool_call_model_name.underscore}.rb"

      template 'model_model.rb.tt', "app/models/#{model_model_name.underscore}.rb"
    end

    def create_initializer
      template 'initializer.rb.tt', 'config/initializers/ruby_llm.rb'
    end

    def install_active_storage
      return if options[:skip_active_storage]

      say '  Installing ActiveStorage for file attachments...', :cyan
      rails_command 'active_storage:install'
    end

    def table_name_for(model_name)
      # Convert namespaced model names to proper table names
      # e.g., "Assistant::Chat" -> "assistant_chats" (not "assistant/chats")
      model_name.underscore.pluralize.tr('/', '_')
    end

    def show_install_info
      say "\n  ✅ RubyLLM installed!", :green

      say '  ✅ ActiveStorage configured for file attachments support', :green unless options[:skip_active_storage]

      say "\n  Next steps:", :yellow
      say '     1. Run: rails db:migrate'
      say '     2. Set your API keys in config/initializers/ruby_llm.rb'

      say "     3. Start chatting: #{chat_model_name}.create!(model: 'gpt-4.1-nano').ask('Hello!')"

      say "\n  🚀 Model registry is database-backed!", :cyan
      say '     Models automatically load from the database'
      say '     Pass model names as strings - RubyLLM handles the rest!'
      say "     Specify provider when needed: Chat.create!(model: 'gemini-2.5-flash', provider: 'vertexai')"

      if options[:skip_active_storage]
        say "\n  📎 Note: ActiveStorage was skipped", :yellow
        say '     File attachments won\'t work without ActiveStorage.'
        say '     To enable later:'
        say '       1. Run: rails active_storage:install && rails db:migrate'
        say "       2. Add to your #{message_model_name} model: has_many_attached :attachments"
      end

      say "\n  📚 Documentation: https://rubyllm.com", :cyan

      say "\n  ❤️  Love RubyLLM?", :magenta
      say '     • ⭐ Star on GitHub: https://github.com/crmne/ruby_llm'
      say '     • 🐦 Follow for updates: https://x.com/paolino'
      say "\n"
    end
  end
end
