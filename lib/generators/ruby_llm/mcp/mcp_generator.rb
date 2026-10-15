# frozen_string_literal: true

require 'rails/generators'
require 'shellwords'

module RubyLLM
  module Generators
    # Generator for MCP server classes.
    class MCPGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      namespace 'ruby_llm:mcp'

      def self.exit_on_failure?
        true
      end

      argument :url, type: :string, required: false, banner: 'URL'

      class_option :command, type: :string, desc: 'The command that starts a local server, for stdio'

      desc "Creates an MCP server class in app/mcp\n" \
           'Usage: bin/rails g ruby_llm:mcp Linear https://mcp.linear.app/mcp ' \
           'or bin/rails g ruby_llm:mcp Files --command "npx -y @modelcontextprotocol/server-filesystem ."'

      def check_server
        return if url.present? ^ options[:command].present?

        raise Thor::Error, "Pass the server's URL or --command, not both"
      end

      def check_server_class_collision
        class_collisions class_name
      end

      def create_server_file
        template 'mcp.rb.tt', File.join('app/mcp', class_path, "#{file_name}.rb")
      end

      private

      def command_arguments
        Shellwords.split(options[:command]).map(&:inspect).join(', ')
      end
    end
  end
end
