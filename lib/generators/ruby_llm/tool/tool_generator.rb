# frozen_string_literal: true

require 'rails/generators'

module RubyLLM
  module Generators
    # Generator for RubyLLM tool classes and related message partials.
    class ToolGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      namespace 'ruby_llm:tool'

      check_class_collision suffix: 'Tool'

      desc 'Creates a RubyLLM tool class and matching tool call/result view partials'

      def create_tool_file
        template 'tool.rb.tt', File.join('app/tools', class_path, "#{file_name}_tool.rb")
      end

      def create_tool_view_partials
        empty_directory 'app/views/messages/tool_calls'
        empty_directory 'app/views/messages/tool_results'

        template 'tool_call.html.erb.tt', File.join('app/views/messages/tool_calls', "_#{tool_partial_name}.html.erb")
        template 'tool_result.html.erb.tt',
                 File.join('app/views/messages/tool_results', "_#{tool_partial_name}.html.erb")
      end

      private

      def tool_partial_name
        file_name.delete_suffix('_tool')
      end
    end
  end
end
