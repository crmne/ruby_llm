# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # Configuration options for Agent SDK queries
    #
    # Supports two styles:
    # 1. Constructor with keyword arguments
    # 2. Fluent builder pattern (with_* methods)
    #
    # @example Constructor style
    #   options = Options.new(
    #     allowed_tools: %w[Read Edit Bash],
    #     permission_mode: :accept_edits,
    #     max_turns: 10
    #   )
    #
    # @example Builder style (matches RubyLLM::Chat)
    #   options = Options.build
    #     .with_tools(:Read, :Edit, :Bash)
    #     .with_permission_mode(:accept_edits)
    #     .with_model(:opus)
    class Options
      # Schema for introspection (agent-native discovery)
      SCHEMA = {
        prompt: { type: String, required: false, description: 'Initial prompt' },
        allowed_tools: { type: Array, default: [], description: 'List of allowed tool names' },
        disallowed_tools: { type: Array, default: [], description: 'List of disallowed tool names' },
        permission_mode: { type: Symbol, default: :default, description: 'Permission mode' },
        model: { type: Symbol, default: nil, description: 'Model to use (opus, sonnet, haiku)' },
        max_turns: { type: Integer, default: nil, description: 'Maximum conversation turns' },
        cwd: { type: String, default: nil, description: 'Working directory' },
        resume: { type: String, default: nil, description: 'Session ID to resume' },
        system_prompt: { type: String, default: nil, description: 'Custom system prompt' },
        mcp_servers: { type: Hash, default: {}, description: 'MCP server configurations' },
        hooks: { type: Hash, default: {}, description: 'Hook configurations' },
        can_use_tool: { type: Proc, default: nil, description: 'Permission callback' },
        env: { type: Hash, default: {}, description: 'Environment variables' },
        timeout: { type: Integer, default: nil, description: 'Timeout in seconds' },
        continue_conversation: { type: :boolean, default: false, description: 'Continue last conversation' },
        fork_session: { type: :boolean, default: false, description: 'Fork when resuming' },
        add_dirs: { type: Array, default: [], description: 'Additional directories to access' },
        include_partial_messages: { type: :boolean, default: false, description: 'Include streaming partials' },
        max_budget_usd: { type: Float, default: nil, description: 'Maximum budget in USD' },
        max_thinking_tokens: { type: Integer, default: nil, description: 'Maximum thinking tokens' }
      }.freeze

      # Define accessors for all options
      attr_accessor(*SCHEMA.keys)

      # @param attrs [Hash] Option values
      def initialize(**attrs)
        SCHEMA.each do |key, config|
          default = config[:default]
          default = default.dup if default.is_a?(Hash) || default.is_a?(Array)
          value = attrs.fetch(key, default)
          instance_variable_set(:"@#{key}", value)
        end
      end

      # Fluent builder: set allowed tools
      #
      # @param tools [Array<String, Symbol>] Tool names
      # @return [self]
      def with_tools(*tools)
        @allowed_tools = tools.flatten.map(&:to_s)
        self
      end

      # Fluent builder: set model
      #
      # @param model [Symbol, String] Model name
      # @return [self]
      def with_model(model)
        @model = model&.to_sym
        self
      end

      # Fluent builder: set permission mode
      #
      # @param mode [Symbol] Permission mode
      # @return [self]
      def with_permission_mode(mode)
        @permission_mode = mode.to_sym
        self
      end

      # Fluent builder: set working directory
      #
      # @param path [String] Directory path
      # @return [self]
      def with_cwd(path)
        @cwd = File.expand_path(path)
        self
      end

      # Fluent builder: set hooks
      #
      # @param hooks [Hash] Hook configuration
      # @return [self]
      def with_hooks(hooks)
        @hooks = hooks
        self
      end

      # Fluent builder: add MCP server
      #
      # @param name [Symbol, String] Server name
      # @param server [MCP::Server] Server configuration
      # @return [self]
      def with_mcp_server(name, server)
        @mcp_servers[name.to_sym] = server
        self
      end

      # Fluent builder: set system prompt
      #
      # @param prompt [String] System prompt
      # @return [self]
      def with_system_prompt(prompt)
        @system_prompt = prompt
        self
      end

      # Fluent builder: set max turns
      #
      # @param turns [Integer] Maximum turns
      # @return [self]
      def with_max_turns(turns)
        @max_turns = turns
        self
      end

      # Fluent builder: set timeout
      #
      # @param seconds [Integer] Timeout in seconds
      # @return [self]
      def with_timeout(seconds)
        @timeout = seconds
        self
      end

      # Check if a tool is allowed
      #
      # @param tool_name [String] Tool name to check
      # @return [Boolean]
      def tool_allowed?(tool_name)
        return false if disallowed_tools.include?(tool_name)
        return true if allowed_tools.empty?

        allowed_tools.include?(tool_name)
      end

      # Class methods for introspection (agent-native)
      class << self
        # Get the options schema
        #
        # @return [Hash]
        def schema
          SCHEMA
        end

        # Get all attribute names
        #
        # @return [Array<Symbol>]
        def attribute_names
          SCHEMA.keys
        end

        # Create a new options instance (for builder pattern)
        #
        # @return [Options]
        def build
          new
        end
      end

      # Convert to hash (excluding nil and empty values)
      #
      # @return [Hash]
      def to_h
        SCHEMA.keys.each_with_object({}) do |key, hash|
          value = send(key)
          next if value.nil?
          next if value.respond_to?(:empty?) && value.empty?

          hash[key] = value
        end
      end

      # Convert to CLI arguments hash
      #
      # @return [Hash]
      def to_cli_args
        {
          cwd: @cwd,
          model: @model,
          max_turns: @max_turns,
          permission_mode: @permission_mode,
          resume: @resume,
          system_prompt: @system_prompt,
          continue_conversation: @continue_conversation,
          timeout: @timeout
        }.compact
      end
    end
  end
end
