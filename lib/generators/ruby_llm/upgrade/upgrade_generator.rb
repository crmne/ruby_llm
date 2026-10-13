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

      desc 'Upgrades a RubyLLM 2.1 Rails schema to 2.2\n' \
           'Usage: bin/rails g ruby_llm:upgrade [chat:ChatName] [message:MessageName]'

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_file
        migration_template 'upgrade_ruby_llm_to_2_2.rb.tt', 'db/migrate/upgrade_ruby_llm_to_2_2.rb'
      end
    end
  end
end
