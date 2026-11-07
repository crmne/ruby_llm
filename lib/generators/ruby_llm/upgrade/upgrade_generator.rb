# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'
require_relative '../generator_helpers'

module RubyLLM
  module Generators
    # Upgrades the schema of an application on RubyLLM 2.1 to 2.2.
    class UpgradeGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      include RubyLLM::Generators::GeneratorHelpers

      namespace 'ruby_llm:upgrade'
      source_root File.expand_path('templates', __dir__)

      argument :model_mappings, type: :array, default: [], banner: 'chat:ChatName message:MessageName'

      desc "Upgrades a RubyLLM 2.1 Rails schema to 2.2\n" \
           'Usage: bin/rails g ruby_llm:upgrade [chat:ChatName] [message:MessageName]'

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_file
        migration_template 'upgrade_ruby_llm_to_2_2.rb.tt', 'db/migrate/upgrade_ruby_llm_to_2_2.rb'
      end

      def create_application_agent_file
        create_application_agent
      end

      def remove_generated_message_code_from_message_model
        return if chat_ui_uses_generated_broadcasting?

        enable_message_broadcasting if remove_generated_message_code
      end

      def install_active_storage
        return if table_exists?('active_storage_blobs')

        rails_command 'active_storage:install'
      end

      def show_next_step
        say "\nRun bin/rails db:migrate" if behavior == :invoke
      end

      private

      def chat_ui_uses_generated_broadcasting?
        return false unless behavior == :invoke

        model = File.join(destination_root, "app/models/#{message_model_name.underscore}.rb")
        return false unless File.exist?(model)

        source = File.read(model)
        return false unless generated_broadcasting_blocks.any? { |block| source.include?(block) }

        stream = %("#{chat_variable_name}_\#{)
        Dir.glob(File.join(destination_root, 'app/**/*.{rb,erb}')).without(model).any? do |path|
          source = File.read(path)
          source.include?('broadcast_append_chunk') || source.include?(stream)
        end
      end
    end
  end
end
