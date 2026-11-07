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
        class_collisions mcp_class_name
      end

      def create_server_file
        template 'mcp.rb.tt', File.join('app/mcp', class_path, "#{mcp_file_name}.rb")
      end

      def explain_next_step
        return unless behavior == :invoke

        say "Connect it by adding #{mcp_class_name} to `mcp` in an agent, or with_mcp(#{mcp_class_name}) on a chat."
      end

      private

      # Follows the application's inflections, so it is LinearMcp, or
      # LinearMCP where MCP is an acronym, as Zeitwerk expects either way.
      def mcp_class_name
        suffix = 'mcp'.camelize
        class_name.end_with?(suffix) ? class_name : "#{class_name}#{suffix}"
      end

      def mcp_file_name
        mcp_class_name.demodulize.underscore
      end

      def command_arguments
        Shellwords.split(options[:command]).map(&:inspect).join(', ')
      end
    end
  end
end
