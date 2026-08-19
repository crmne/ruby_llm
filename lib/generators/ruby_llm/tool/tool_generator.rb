# frozen_string_literal: true

require 'rails/generators'
require_relative '../generator_helpers'

module RubyLLM
  module Generators
    # Generator for RubyLLM tool classes and related message partials.
    class ToolGenerator < Rails::Generators::NamedBase
      include RubyLLM::Generators::GeneratorHelpers

      source_root File.expand_path('templates', __dir__)

      namespace 'ruby_llm:tool'

      argument :model_mappings, type: :array, default: [], banner: 'message:MessageName'

      class_option :ui, type: :string, default: 'auto', enum: %w[scaffold tailwind auto],
                        desc: 'UI template style (scaffold, tailwind, auto)'

      desc 'Creates a RubyLLM tool class and matching tool call/result view partials'

      def check_tool_class_collision
        class_collisions tool_class_name
      end

      def create_tool_file
        template 'tool.rb.tt', File.join('app/tools', class_path, "#{tool_file_name}.rb")
      end

      def create_tool_view_partials
        template ui_template('tool_call.html.erb'),
                 File.join(message_view_path, 'tool_calls', "_#{tool_partial_name}.html.erb")
        template ui_template('tool_result.html.erb'),
                 File.join(message_view_path, 'tool_results', "_#{tool_partial_name}.html.erb")
      end

      private

      def message_view_path
        File.join('app/views', message_model_name.underscore.pluralize)
      end

      def tool_class_name
        class_name.end_with?('Tool') ? class_name : "#{class_name}Tool"
      end

      def tool_file_name
        tool_class_name.demodulize.underscore
      end

      def tool_display_name
        tool_class_name.demodulize.delete_suffix('Tool')
      end

      # Mirrors RubyLLM::Tool.tool_name, the key the runtime partial lookup uses.
      def tool_partial_name
        tool_file_name.delete_suffix('_tool')
      end
    end
  end
end
