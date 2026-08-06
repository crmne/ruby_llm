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

      argument :model_mappings,
               type: :array,
               default: [],
               banner: 'chat:ChatName message:MessageName model:ModelName tool_call:ToolCallName batch:BatchName'

      desc 'Adds the columns and tables introduced in the latest RubyLLM version ' \
           '(v2.0: internal usage, tool-call, model-registry, and batch storage)'

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_file
        parse_model_mappings

        migration_template 'add_v2_0_message_columns.rb.tt',
                           'db/migrate/add_ruby_llm_v2_0_columns.rb',
                           migration_version: migration_version,
                           chat_table_name: chat_table_name,
                           message_table_name: message_table_name,
                           message_model_name: message_model_name,
                           legacy_model_table_name: legacy_table_name(:model, 'Model'),
                           legacy_tool_call_table_name: legacy_table_name(:tool_call, 'ToolCall'),
                           legacy_batch_table_name: legacy_table_name(:batch, 'Batch'),
                           legacy_model_foreign_key: "#{legacy_table_name(:model, 'Model').singularize}_id",
                           legacy_tool_call_message_foreign_key: "#{message_table_name.singularize}_id",
                           legacy_message_tool_call_foreign_key:
                             "#{legacy_table_name(:tool_call, 'ToolCall').singularize}_id"
      end

      def show_next_steps
        say_status :success, 'Upgrade prepared!', :green
        say <<~INSTRUCTIONS

          Next steps:
          1. Review the generated migration
          2. Run: bin/rails db:migrate
          3. Remove RubyLLM's old application-owned model files:
             #{obsolete_model_paths.join("\n     ")}
          4. Keep only the current declarations in your application models:
             #{chat_model_path}: #{acts_as_chat_declaration}
             #{message_model_path}: #{acts_as_message_declaration}
          5. Remove config.model_registry_class from config/initializers/ruby_llm.rb, if present
          6. Review the generated Chat UI files listed below, if present
          7. Restart your application server

          Generated UI files that reference the old records:
          #{generated_ui_paths.any? ? generated_ui_paths.join("\n  ") : '(none detected)'}

          📚 See the v2.0 release notes for details on citations, finish reasons, prompt caching, cancellation, and batches support.

        INSTRUCTIONS
      end

      private

      def legacy_model_name(type, default)
        mapping = model_mappings.find { |item| item.start_with?("#{type}:") }
        mapping ? mapping.split(':', 2).last.classify : default
      end

      def legacy_table_name(type, default)
        table_name_for(legacy_model_name(type, default))
      end

      def legacy_model_table_name
        legacy_table_name(:model, 'Model')
      end

      def legacy_tool_call_table_name
        legacy_table_name(:tool_call, 'ToolCall')
      end

      def legacy_batch_table_name
        legacy_table_name(:batch, 'Batch')
      end

      def legacy_model_foreign_key
        "#{legacy_model_table_name.singularize}_id"
      end

      def legacy_tool_call_message_foreign_key
        "#{message_table_name.singularize}_id"
      end

      def legacy_message_tool_call_foreign_key
        "#{legacy_tool_call_table_name.singularize}_id"
      end

      def chat_model_path
        "app/models/#{chat_model_name.underscore}.rb"
      end

      def message_model_path
        "app/models/#{message_model_name.underscore}.rb"
      end

      def obsolete_model_paths
        {
          model: 'Model',
          tool_call: 'ToolCall',
          batch: 'Batch'
        }.map do |type, default|
          "app/models/#{legacy_model_name(type, default).underscore}.rb"
        end
      end

      def generated_ui_paths
        model_path = legacy_model_name(:model, 'Model').underscore.pluralize
        message_path = message_model_name.underscore.pluralize
        paths = [
          "app/controllers/#{model_path}_controller.rb",
          "app/views/#{model_path}/index.html.erb",
          "app/views/#{model_path}/show.html.erb",
          "app/views/#{model_path}/_#{legacy_model_name(:model, 'Model').demodulize.underscore}.html.erb",
          "app/views/#{message_path}/_tool_calls.html.erb"
        ]
        paths.select { |path| File.exist?(Rails.root.join(path)) }
      end
    end
  end
end
