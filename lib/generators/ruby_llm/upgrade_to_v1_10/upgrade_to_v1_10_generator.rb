# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'
require_relative '../generator_helpers'

module RubyLLM
  module Generators
    # Generator to add v1.10 columns (thinking output + thinking tokens) to existing apps.
    class UpgradeToV110Generator < Rails::Generators::Base
      include Rails::Generators::Migration
      include RubyLLM::Generators::GeneratorHelpers

      namespace 'ruby_llm:upgrade_to_v1_10'
      source_root File.expand_path('templates', __dir__)

      argument :model_mappings, type: :array, default: [], banner: 'message:MessageName'

      desc 'Adds thinking output columns and thinking token tracking introduced in v1.10.0'

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_file
        parse_model_mappings

        migration_template 'add_v1_10_message_columns.rb.tt',
                           'db/migrate/add_ruby_llm_v1_10_columns.rb',
                           migration_version: migration_version,
                           message_table_name: message_table_name,
                           tool_call_table_name: tool_call_table_name
      end

      def show_next_steps
        say_status :success, 'Upgrade prepared!', :green
        say <<~INSTRUCTIONS

          Next steps:
          1. Review the generated migration
          2. Run: rails db:migrate
          3. Restart your application server

          📚 See the v1.10.0 release notes for details on extended thinking support.

        INSTRUCTIONS
      end
    end
  end
end
