# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module RubyLLM
  class UpgradeToV17Generator < Rails::Generators::Base # rubocop:disable Style/Documentation
    include Rails::Generators::Migration

    namespace 'ruby_llm:upgrade_to_v1_7'
    source_root File.expand_path('upgrade_to_v1_7/templates', __dir__)

    # Override source_paths to include install templates
    def self.source_paths
      [
        File.expand_path('upgrade_to_v1_7/templates', __dir__),
        File.expand_path('install/templates', __dir__)
      ]
    end

    argument :model_mappings, type: :array, default: [], banner: 'chat:ChatName message:MessageName ...'

    desc 'Upgrades existing RubyLLM apps to v1.7 with new Rails-like API\n' \
         'Usage: rails g ruby_llm:upgrade_to_v1_7 [chat:ChatName] [message:MessageName] ...'

    def self.next_migration_number(dirname)
      ::ActiveRecord::Generators::Base.next_migration_number(dirname)
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

    def table_name_for(model_name)
      # Convert namespaced model names to proper table names
      # e.g., "Assistant::Chat" -> "assistant_chats" (not "assistant/chats")
      model_name.underscore.pluralize.tr('/', '_')
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

    def create_migration_file
      # First check if models table exists, if not create it
      unless table_exists?(table_name_for(model_model_name))
        migration_template 'create_models_migration.rb.tt',
                           "db/migrate/create_#{table_name_for(model_model_name)}.rb",
                           migration_version: migration_version,
                           model_model_name: model_model_name

        sleep 1 # Ensure different timestamp
      end

      migration_template 'migration.rb.tt',
                         'db/migrate/migrate_to_ruby_llm_model_references.rb',
                         migration_version: migration_version,
                         chat_model_name: chat_model_name,
                         message_model_name: message_model_name,
                         tool_call_model_name: tool_call_model_name,
                         model_model_name: model_model_name
    end

    def create_model_file
      # Check if Model file already exists
      model_path = "app/models/#{model_model_name.underscore}.rb"

      if File.exist?(Rails.root.join(model_path))
        say_status :skip, model_path, :yellow
      else
        create_file model_path do
          <<~RUBY
            class #{model_model_name} < ApplicationRecord
              #{acts_as_model_declaration}
            end
          RUBY
        end
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

    def update_initializer
      initializer_content = File.read('config/initializers/ruby_llm.rb')

      unless initializer_content.include?('config.use_new_acts_as')
        inject_into_file 'config/initializers/ruby_llm.rb', before: /^end/ do
          lines = ["\n  # Enable the new Rails-like API", '  config.use_new_acts_as = true']
          lines << "  config.model_registry_class = \"#{model_model_name}\"" if model_model_name != 'Model'
          lines << "\n"
          lines.join("\n")
        end
      end
    rescue Errno::ENOENT
      say_status :error, 'config/initializers/ruby_llm.rb not found', :red
    end

    def show_next_steps
      say_status :success, 'Migration created!', :green
      say <<~INSTRUCTIONS

        Next steps:
        1. Review the migration: db/migrate/*_migrate_to_ruby_llm_model_references.rb
        2. Run: rails db:migrate
        3. Update config/initializers/ruby_llm.rb as shown above
        4. Test your application thoroughly

        The migration will:
        - Create the Models table if it doesn't exist
        - Load all models from models.json
        - Migrate your existing data to use foreign keys
        - Preserve all existing data (string columns renamed to model_id_string)

      INSTRUCTIONS
    end

    private

    def migration_version
      "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
    end

    def table_exists?(table_name)
      ::ActiveRecord::Base.connection.table_exists?(table_name)
    rescue StandardError
      false
    end

    def postgresql?
      ::ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
    rescue StandardError
      false
    end
  end
end
