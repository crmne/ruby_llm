# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'
require_relative '../generator_helpers'

module RubyLLM
  module Generators
    # Brings an existing app's schema up to date with the latest RubyLLM version.
    # Run it after upgrading the gem; it always targets the current release.
    class UpgradeGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      include RubyLLM::Generators::GeneratorHelpers

      namespace 'ruby_llm:upgrade'
      source_root File.expand_path('templates', __dir__)

      argument :model_mappings, type: :array, default: [], banner: 'message:MessageName'

      desc 'Adds the columns and tables introduced in the latest RubyLLM version ' \
           '(v2.0: citations, finish reasons, batches)'

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_file
        parse_model_mappings

        migration_template 'add_v2_0_message_columns.rb.tt',
                           'db/migrate/add_ruby_llm_v2_0_columns.rb',
                           migration_version: migration_version,
                           message_table_name: message_table_name,
                           batch_table_name: batch_table_name
      end

      def show_next_steps
        say_status :success, 'Upgrade prepared!', :green
        say <<~INSTRUCTIONS

          Next steps:
          1. Review the generated migration
          2. Run: bin/rails db:migrate
          3. Restart your application server

          📚 See the v2.0 release notes for details on citations, finish reasons, and batches support.

        INSTRUCTIONS
      end
    end
  end
end
