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
  # == API Naming: Why `query` instead of `ask`?
  #
  # AgentSDK uses `query` rather than `ask` (which Chat uses) for several reasons:
  #
  # 1. **Streaming semantics**: `query` returns an Enumerator that streams messages
  #    as they arrive, rather than blocking until a final response. This is
  #    fundamentally different from Chat#ask which returns a single Message.
  #
  # 2. **SDK parity**: The `query` method aligns with the official Claude Code SDK's
  #    naming conventions, making it easier for developers familiar with the
  #    official SDK to adopt RubyLLM's AgentSDK.
  #
  # 3. **Semantic distinction**: `ask` implies a question-and-answer interaction,
  #    while `query` better represents a command-and-stream interaction where
  #    the agent may perform multiple actions and emit multiple messages.
  #
  # == Usage Comparison
  #
  #   # Chat (synchronous, returns single Message)
  #   message = chat.ask("What is 2+2?")
  #   puts message.content  # => "4"
  #
  #   # AgentSDK (streaming, returns Enumerator of Messages)
  #   RubyLLM::AgentSDK.query("Analyze this codebase").each do |message|
  #     puts message.content if message.assistant?
  #   end
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
  # @example Collecting final result
  #   result = RubyLLM::AgentSDK.query("What is 2+2?").find(&:result?)
  #   puts result.content  # => "4"
  #
  module AgentSDK
    class << self
      # One-off query - streams messages from Claude Code CLI
      #
      # @param prompt [String] The prompt to send
      # @param options [Hash] Additional options
      # @yield [Message] Block to receive each message (optional)
      # @return [Enumerator::Lazy<Message>] Stream of messages (if no block given)
      #
      # @example With block
      #   RubyLLM::AgentSDK.query("Hello") do |message|
      #     puts message.content if message.assistant?
      #   end
      #
      # @example With enumerator
      #   RubyLLM::AgentSDK.query("Hello").each { |msg| puts msg.content }
      #
      def query(prompt = nil, **options, &block)
        opts = Options.new(**options)
        hook_runner = Hooks::Runner.new(opts.hooks)
        session_context = {}

        enumerator = Enumerator.new do |yielder|
          cli = CLI.new(opts.to_cli_args)

          cli.stream(prompt || opts.prompt) do |line|
            message = Stream.parse(line)
            next unless message

            # Capture session context from init message
            if message.init?
              session_context[:session_id] = message.session_id
              session_context[:cwd] = message.cwd
              session_context[:permission_mode] = message.permission_mode

              # Fire session_start hook
              hook_runner.run(
                :session_start,
                metadata: { source: 'startup', **session_context }
              )
            end

            # Fire pre_tool_use hooks for tool use messages
            if message.tool_use?
              blocked = false
              message.tool_use_blocks.each do |tool_block|
                result = hook_runner.run(
                  :pre_tool_use,
                  tool_name: tool_block[:name],
                  tool_input: tool_block[:input],
                  metadata: { tool_use_id: tool_block[:id], **session_context }
                )

                # If any hook blocks, skip yielding this message
                # Note: This doesn't stop CLI execution, just filters output
                if result.blocked?
                  blocked = true
                  break
                end
              end
              next if blocked
            end

            yielder << message
          end

          # Fire session_end hook
          hook_runner.run(
            :session_end,
            metadata: { reason: 'completed', **session_context }
          )
        end

        if block_given?
          enumerator.each(&block)
        else
          enumerator.lazy
        end
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
