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

        create_tool_call_partial
        create_tool_result_partial
      end

      private

      def create_tool_call_partial
        destination_path = File.join('app/views/messages/tool_calls', "_#{tool_partial_name}.html.erb")
        default_partial_path = File.join(destination_root, 'app/views/messages/tool_calls/_default.html.erb')

        if File.exist?(default_partial_path)
          default_markup = tool_named_call_markup(File.read(default_partial_path))
          indented_markup = indent_non_empty_lines(default_markup, 2)
          create_file destination_path, <<~ERB
            <% tool_call_error = tool_call.tool_error_message %>
            <% if tool_call_error.present? %>
              <%= render "messages/error", message: tool_calls, title: "Tool Call Error", error_message: tool_call_error %>
            <% else %>
            #{indented_markup}<% end %>
          ERB
        else
          template 'tool_call.html.erb.tt', destination_path
        end

        strip_trailing_whitespace(destination_path)
      end

      def create_tool_result_partial
        destination_path = File.join('app/views/messages/tool_results', "_#{tool_partial_name}.html.erb")
        default_partial_path = File.join(destination_root, 'app/views/messages/tool_results/_default.html.erb')

        if File.exist?(default_partial_path)
          create_file destination_path, tool_named_result_markup(File.read(default_partial_path))
        else
          template 'tool_result.html.erb.tt', destination_path
        end

        strip_trailing_whitespace(destination_path)
      end

      def tool_named_call_markup(markup)
        markup.sub('Tool Call', "#{tool_display_name} Call")
      end

      def tool_named_result_markup(markup)
        markup.sub(/\bTool\b(?!\s*Result)/, "#{tool_display_name} Result")
      end

      def tool_display_name
        class_name.demodulize
      end

      def tool_partial_name
        file_name.delete_suffix('_tool')
      end

      def indent_non_empty_lines(markup, spaces)
        indentation = ' ' * spaces
        markup.lines.map { |line| line.strip.empty? ? line : "#{indentation}#{line}" }.join
      end

      def strip_trailing_whitespace(path)
        content = File.read(path)
        stripped_content = content.lines.map(&:rstrip).join("\n")
        stripped_content = "#{stripped_content}\n" unless stripped_content.end_with?("\n")
        return if content == stripped_content

        File.write(path, stripped_content)
      end
    end
  end
end
