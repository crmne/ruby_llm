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

          IMPORTANT: The 2.0 migration renames tables and removes columns used by 1.x.
          Stop web processes and background workers before running it, then deploy 2.0
          before accepting traffic again. Rehearse it on a recent production snapshot.

          Next steps:
          1. Review the generated migration
          2. Schedule a maintenance window and stop every process that writes chats
          3. Run: bin/rails db:migrate
          4. Remove RubyLLM's old application-owned model files:
             #{obsolete_model_paths.join("\n     ")}
          5. Keep only the current declarations in your application models:
             #{chat_model_path}: #{acts_as_chat_declaration}
             #{message_model_path}: #{acts_as_message_declaration}
          6. Remove config.model_registry_class from config/initializers/ruby_llm.rb, if present
          7. Review the generated Chat UI files listed below, if present
          8. Grep your app for the 1.x names and update them:
               input_tokens, output_tokens, cached_tokens  ->  tokens.input / tokens.output / tokens.cache_read
               RubyLLM::Content, content_raw               ->  String content plus message.attachments
               create_user_message                         ->  ask_later or add_message
               on_new_message, on_tool_call                ->  before_message, before_tool_call
               halt, Tool::Halt                            ->  loop verbs or requires_approval
               with_params, params:                        ->  with_provider_options, provider_options:
          9. Deploy 2.0, restart your processes, and end the maintenance window

          Generated UI files that reference the old records:
          #{generated_ui_paths.any? ? generated_ui_paths.join("\n  ") : '(none detected)'}

          📚 The full upgrade guide, including the complete rename table:
             https://rubyllm.com/upgrading/

        INSTRUCTIONS
      end

      private

      def legacy_model_name(type, default)
        mapping = model_mappings.find { |item| item.start_with?("#{type}:") }
        mapping ? mapping.split(':', 2).last.classify : default
      end

      def model_mapping?(type)
        model_mappings.any? { |item| item.start_with?("#{type}:") }
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

      def legacy_batch_explicit?
        model_mapping?(:batch)
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
        models = {
          model: 'Model',
          tool_call: 'ToolCall'
        }
        models[:batch] = 'Batch' if legacy_batch_model?
        models.map do |type, default|
          "app/models/#{legacy_model_name(type, default).underscore}.rb"
        end
      end

      def legacy_batch_model?
        return true if model_mapping?(:batch)
        return false unless table_exists?(legacy_batch_table_name)

        columns = ::ActiveRecord::Base.connection.columns(legacy_batch_table_name).map(&:name)
        %w[provider_batch_id provider status completed chat_ids created_at updated_at].all? do |column|
          columns.include?(column)
        end
      rescue StandardError
        false
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
