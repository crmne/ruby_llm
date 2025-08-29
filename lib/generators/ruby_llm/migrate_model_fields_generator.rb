# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module RubyLLM
  class MigrateModelFieldsGenerator < Rails::Generators::Base # rubocop:disable Style/Documentation
    include Rails::Generators::Migration

    namespace 'ruby_llm:migrate_model_fields'
    source_root File.expand_path('migrate_model_fields/templates', __dir__)

    class_option :chat_model_name, type: :string, default: 'Chat'
    class_option :message_model_name, type: :string, default: 'Message'
    class_option :model_model_name, type: :string, default: 'Model'
    class_option :tool_call_model_name, type: :string, default: 'ToolCall'

    def self.next_migration_number(dirname)
      ::ActiveRecord::Generators::Base.next_migration_number(dirname)
    end

    def create_migration_file
      migration_template 'migration.rb.tt',
                         'db/migrate/migrate_to_ruby_llm_model_references.rb',
                         migration_version: migration_version
    end

    def create_model_file
      # Check if Model file already exists
      model_path = "app/models/#{options[:model_model_name].underscore}.rb"

      if File.exist?(Rails.root.join(model_path))
        say_status :skip, model_path, :yellow
      else
        create_file model_path do
          <<~RUBY
            class #{options[:model_model_name]} < ApplicationRecord
              acts_as_model
            end
          RUBY
        end
      end
    end

    def acts_as_model_declaration
      'acts_as_model'
    end

    def update_initializer
      say_status :info, 'Update your config/initializers/ruby_llm.rb:', :yellow
      say <<~INSTRUCTIONS

        Add this line to enable the DB-backed model registry:
          config.model_registry_class = "#{options[:model_model_name]}"

      INSTRUCTIONS
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
  end
end
