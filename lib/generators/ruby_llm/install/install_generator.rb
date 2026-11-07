# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'
require_relative '../generator_helpers'

module RubyLLM
  module Generators
    # Generator for RubyLLM Rails models and migrations
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      include RubyLLM::Generators::GeneratorHelpers

      namespace 'ruby_llm:install'

      source_root File.expand_path('templates', __dir__)

      argument :model_mappings, type: :array, default: [], banner: 'chat:ChatName message:MessageName ...'

      desc "Creates models and migrations for RubyLLM Rails integration\n" \
           'Usage: bin/rails g ruby_llm:install [chat:ChatName] [message:MessageName] ...'

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_files
        migration_template 'create_ruby_llm_records_migration.rb.tt',
                           'db/migrate/create_ruby_llm_records.rb'
        migration_template 'create_chats_migration.rb.tt',
                           "db/migrate/create_#{chat_table_name}.rb"
        migration_template 'create_messages_migration.rb.tt',
                           "db/migrate/create_#{message_table_name}.rb"
      end

      def create_model_files
        create_namespace_modules

        template 'chat_model.rb.tt', "app/models/#{chat_model_name.underscore}.rb"
        template 'message_model.rb.tt', "app/models/#{message_model_name.underscore}.rb"
      end

      def create_initializer
        template 'initializer.rb.tt', 'config/initializers/ruby_llm.rb'
      end

      def create_application_agent_file
        create_application_agent
      end

      def install_active_storage
        rails_command 'active_storage:install'
      end

      def show_next_step
        say "\nRun bin/rails db:migrate" if behavior == :invoke
      end
    end
  end
end
