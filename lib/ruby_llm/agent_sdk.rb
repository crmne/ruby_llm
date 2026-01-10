# frozen_string_literal: true

require_relative 'agent_sdk/version'
require_relative 'agent_sdk/errors'
require_relative 'agent_sdk/permissions'
require_relative 'agent_sdk/hooks'
require_relative 'agent_sdk/message'
require_relative 'agent_sdk/stream'
require_relative 'agent_sdk/options'
require_relative 'agent_sdk/cli'
require_relative 'agent_sdk/tool'
require_relative 'agent_sdk/mcp'
require_relative 'agent_sdk/client'
require_relative 'agent_sdk/session'
require_relative 'agent_sdk/introspection'

module RubyLLM
  # AgentSDK provides a Ruby interface to Claude Code CLI.
  #
  # This module enables programmatic control of Claude Code, allowing Ruby
  # applications to spawn autonomous agents, manage permissions, define
  # custom tools, and handle streaming responses.
  #
  # @example One-off query
  #   RubyLLM::AgentSDK.query("What is 2+2?").each do |message|
  #     puts message.content if message.assistant?
  #   end
  #
  # @example Multi-turn conversation
  #   client = RubyLLM::AgentSDK.client(model: :claude_sonnet)
  #   client.query("Hello!").each { |msg| puts msg.content }
  #   client.query("What did I just say?").each { |msg| puts msg.content }
  #
  # @example Custom tools
  #   weather_tool = RubyLLM::AgentSDK.tool(
  #     name: "get_weather",
  #     description: "Get current weather for a location"
  #   ) { |args| "Sunny in #{args[:location]}" }
  #
  module AgentSDK
    class << self
      # One-off query - returns Enumerator of Messages
      #
      # @param prompt [String] The prompt to send
      # @param options [Hash] Additional options
      # @return [Enumerator::Lazy<Message>] Stream of messages
      def query(prompt = nil, **options)
        opts = Options.new(**options)
        hook_runner = Hooks::Runner.new(opts.hooks)

        Enumerator.new do |yielder|
          cli = CLI.new(opts.to_cli_args)

          cli.stream(prompt || opts.prompt) do |line|
            message = Stream.parse(line)
            next unless message

            yielder << message
          end
        end.lazy
      end

      # Create multi-turn client
      #
      # @param options [Hash] Client options
      # @return [Client] A new client instance
      def client(**options)
        Client.new(**options)
      end

      # Define custom tool
      #
      # @param name [String] Tool name
      # @param description [String] Tool description
      # @param input_schema [Hash] JSON Schema for tool input
      # @yield [Hash] Tool handler block
      # @return [Tool] A new tool instance
      def tool(name:, description:, input_schema: {}, &handler)
        Tool.new(name: name, description: description, input_schema: input_schema, &handler)
      end

      # Create MCP server for Ruby tools
      #
      # @param tools [Array<Tool>] Tools to expose via MCP
      # @return [MCP::Server] A new MCP server
      def create_sdk_mcp_server(tools:)
        MCP::Server.ruby(tools: tools)
      end

      # Create stdio MCP server configuration
      #
      # @param command [String] Command to run
      # @param args [Array<String>] Command arguments
      # @param env [Hash] Environment variables
      # @return [MCP::Server] A new MCP server config
      def stdio_mcp_server(command:, args: [], env: {})
        MCP::Server.stdio(command: command, args: args, env: env)
      end

      # Introspection methods (agent-native)
      def cli_available?
        Introspection.cli_available?
      end

      def cli_version
        Introspection.cli_version
      end

      def requirements_met?
        Introspection.requirements_met?
      end

      def builtin_tools
        Introspection.builtin_tools
      end

      def hook_events
        Introspection.hook_events
      end

      def permission_modes
        Introspection.permission_modes
      end

      def options_schema
        Introspection.options_schema
      end
    end
  end
end
