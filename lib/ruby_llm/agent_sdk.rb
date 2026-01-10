# frozen_string_literal: true

require_relative 'agent_sdk/version'
require_relative 'agent_sdk/errors'
require_relative 'agent_sdk/permission_mode'
require_relative 'agent_sdk/permissions'
require_relative 'agent_sdk/hooks'
require_relative 'agent_sdk/stream'
require_relative 'agent_sdk/message'
require_relative 'agent_sdk/options'
require_relative 'agent_sdk/tool'
require_relative 'agent_sdk/mcp'
require_relative 'agent_sdk/cli'
require_relative 'agent_sdk/session'
require_relative 'agent_sdk/client'
require_relative 'agent_sdk/introspection'

# Legacy support - load if they exist
begin
  require_relative 'agent_sdk/agent_options'
  require_relative 'agent_sdk/agent_definition'
rescue LoadError
  # These are optional legacy files
end

module RubyLLM
  # Agent SDK - A Ruby port of the Claude Agent SDK
  #
  # Build AI agents that autonomously read files, run commands, search the web,
  # edit code, and more. The Agent SDK gives you the same tools, agent loop,
  # and context management that power Claude Code.
  #
  # @example Basic query
  #   RubyLLM::AgentSDK.query("Find and fix the bug in auth.rb") do |message|
  #     puts message.content if message.assistant?
  #   end
  #
  # @example Streaming with options
  #   RubyLLM::AgentSDK.stream("Analyze the codebase",
  #     permission_mode: :accept_edits,
  #     max_turns: 5
  #   ).each do |message|
  #     process(message)
  #   end
  #
  # @example Multi-turn conversation
  #   client = RubyLLM::AgentSDK.client(permission_mode: :accept_edits)
  #   client.query("What's in this file?") { |m| puts m.content }
  #   client.query("Now fix the bug") { |m| puts m.content }
  #
  # @example Custom tools
  #   weather = RubyLLM::AgentSDK.tool(
  #     name: 'get_weather',
  #     description: 'Get current weather',
  #     input_schema: { location: { type: :string } }
  #   ) { |input| fetch_weather(input[:location]) }
  #
  #   client = RubyLLM::AgentSDK.client
  #   client.register_tool(weather)
  #
  module AgentSDK
    class << self
      # Execute a one-shot query against Claude
      #
      # @param prompt [String] The prompt to send
      # @param options [Hash] Configuration options
      # @yield [Message] Each message as it arrives
      # @return [Message, nil] The final result message
      #
      # @example
      #   result = RubyLLM::AgentSDK.query("What is 2+2?") do |msg|
      #     puts msg.content if msg.assistant?
      #   end
      #   puts "Session: #{result.session_id}"
      def query(prompt, **options, &block)
        cli = CLI.new(options: Options.new(**options))
        cli.query(prompt, &block)
      end

      # Stream messages from a query as an Enumerator
      #
      # @param prompt [String] The prompt to send
      # @param options [Hash] Configuration options
      # @return [Enumerator<Message>]
      #
      # @example
      #   RubyLLM::AgentSDK.stream("Analyze code").each do |message|
      #     case message.type
      #     when :assistant then print message.content
      #     when :tool_use then log_tool(message)
      #     when :result then done(message)
      #     end
      #   end
      def stream(prompt, **options)
        cli = CLI.new(options: Options.new(**options))
        cli.stream(prompt)
      end

      # Create a client for multi-turn conversations
      #
      # @param options [Hash] Configuration options
      # @return [Client] Client instance
      #
      # @example
      #   client = RubyLLM::AgentSDK.client(permission_mode: :accept_edits)
      #   client.query("Start a task")
      #   client.query("Continue the task")  # Remembers context
      def client(**options)
        Client.new(**options)
      end

      # Create a custom tool
      #
      # @param name [String, Symbol] Tool name
      # @param description [String] What the tool does
      # @param input_schema [Hash] JSON Schema for input
      # @yield [Hash] Tool input parameters
      # @return [Tool]
      #
      # @example
      #   calculator = RubyLLM::AgentSDK.tool(
      #     name: 'calculate',
      #     description: 'Evaluates a math expression',
      #     input_schema: {
      #       type: :object,
      #       properties: { expression: { type: :string } },
      #       required: [:expression]
      #     }
      #   ) do |input|
      #     eval(input[:expression]).to_s
      #   end
      def tool(name:, description:, input_schema: {}, &handler)
        Tool.new(name: name, description: description, input_schema: input_schema, &handler)
      end

      # Create an MCP server configuration
      #
      # @param name [String] Server name
      # @param transport [Symbol] Transport type (:stdio, :sse, :http, :sdk)
      # @param config [Hash] Transport-specific config
      # @return [MCP::Server]
      #
      # @example Stdio server
      #   server = RubyLLM::AgentSDK.mcp_server(
      #     'filesystem',
      #     transport: :stdio,
      #     command: 'npx',
      #     args: ['-y', '@anthropic/mcp-server-filesystem', '/tmp']
      #   )
      def mcp_server(name, transport:, **config)
        MCP::Server.new(name: name, transport: transport, **config)
      end

      # Build options using the fluent interface
      #
      # @return [Options]
      #
      # @example
      #   options = RubyLLM::AgentSDK.options
      #     .with_tools(:Read, :Edit, :Bash)
      #     .with_permission_mode(:accept_edits)
      #     .with_max_turns(10)
      def options
        Options.build
      end

      # Get SDK introspection schema
      #
      # @return [Hash] Full SDK schema for agent-native discovery
      def schema
        Introspection.schema
      end

      # Generate capabilities prompt for agents
      #
      # @param client [Client, nil] Optional client to include custom tools
      # @return [String] Markdown prompt describing capabilities
      def capabilities_prompt(client = nil)
        Introspection.generate_capabilities_prompt(client)
      end

      # Check if Claude CLI is available
      #
      # @return [Boolean]
      def available?
        CLI.available?
      end

      # Get Claude CLI version
      #
      # @return [String, nil]
      def cli_version
        CLI.version
      end

      # Check if a capability is supported
      #
      # @param capability [Symbol] Capability to check
      # @return [Boolean]
      def supports?(capability)
        Introspection.supports?(capability)
      end

      # Validate configuration
      #
      # @param config [Hash] Configuration to validate
      # @return [Array<String>] List of validation errors (empty if valid)
      def validate_config(config)
        Introspection.validate_config(config)
      end
    end
  end
end
