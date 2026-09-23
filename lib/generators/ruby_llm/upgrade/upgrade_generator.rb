# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'
require_relative '../generator_helpers'

module RubyLLM
  module Generators
    # Upgrades the schema of an application on RubyLLM 2.0 to 2.1.
    class UpgradeGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      include RubyLLM::Generators::GeneratorHelpers

      namespace 'ruby_llm:upgrade'
      source_root File.expand_path('templates', __dir__)

      desc 'Upgrades a RubyLLM 2.0 Rails schema to 2.1'

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_file
        migration_template 'upgrade_ruby_llm_to_2_1.rb.tt', 'db/migrate/upgrade_ruby_llm_to_2_1.rb'
      end
    end
  end
end
