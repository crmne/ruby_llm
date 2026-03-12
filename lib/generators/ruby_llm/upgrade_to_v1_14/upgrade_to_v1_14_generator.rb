# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'
require_relative '../generator_helpers'

module RubyLLM
  module Generators
    # Generator to fix tool call thought signature column type for MySQL safety.
    class UpgradeToV114Generator < Rails::Generators::Base
      include Rails::Generators::Migration
      include RubyLLM::Generators::GeneratorHelpers

      namespace 'ruby_llm:upgrade_to_v1_14'
      source_root File.expand_path('templates', __dir__)

      argument :model_mappings, type: :array, default: [], banner: 'tool_call:ToolCallName'

      desc 'Updates tool call thought_signature column to text introduced in v1.14.0'

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_file
        parse_model_mappings

        migration_template 'add_v1_14_tool_call_columns.rb.tt',
                           'db/migrate/add_ruby_llm_v1_14_columns.rb',
                           migration_version: migration_version,
                           tool_call_table_name: tool_call_table_name
      end

      def show_next_steps
        say_status :success, 'Upgrade prepared!', :green
        say <<~INSTRUCTIONS

          Next steps:
          1. Review the generated migration
          2. Run: bin/rails db:migrate
          3. Restart your application server

          📚 See the v1.14.0 release notes for details on thought signature persistence.

        INSTRUCTIONS
      end
    end
  end
end
