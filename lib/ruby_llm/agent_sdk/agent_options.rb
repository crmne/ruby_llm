# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # Configuration options for Claude Agent SDK queries
    #
    # Mirrors ClaudeAgentOptions from the Python/TypeScript SDKs.
    #
    # @example Basic options
    #   options = AgentOptions.new(
    #     allowed_tools: %w[Read Edit Bash],
    #     permission_mode: :accept_edits
    #   )
    #
    # @example With hooks and subagents
    #   options = AgentOptions.new(
    #     allowed_tools: %w[Read Glob Grep Task],
    #     hooks: {
    #       pre_tool_use: [HookMatcher.new(matcher: 'Bash', hooks: [my_hook])]
    #     },
    #     agents: {
    #       'code-reviewer' => AgentDefinition.new(
    #         description: 'Reviews code for quality',
    #         prompt: 'You are a code review specialist...',
    #         tools: %w[Read Glob Grep]
    #       )
    #     }
    #   )
    #
    class AgentOptions
      # @return [Array<String>] List of allowed tool names
      attr_accessor :allowed_tools

      # @return [Array<String>] List of disallowed tool names
      attr_accessor :disallowed_tools

      # @return [String, Hash, nil] System prompt configuration
      #   Pass a string for custom prompt, or use
      #   { type: :preset, preset: :claude_code } for Claude Code's system prompt
      attr_accessor :system_prompt

      # @return [Hash<String, MCP::ServerConfig>] MCP server configurations
      attr_accessor :mcp_servers

      # @return [Symbol] Permission mode (:default, :accept_edits, :bypass_permissions, :plan)
      attr_accessor :permission_mode

      # @return [Boolean] Continue the most recent conversation
      attr_accessor :continue_conversation

      # @return [String, nil] Session ID to resume
      attr_accessor :resume

      # @return [Boolean] Fork to a new session when resuming
      attr_accessor :fork_session

      # @return [Integer, nil] Maximum conversation turns
      attr_accessor :max_turns

      # @return [String, nil] Model to use
      attr_accessor :model

      # @return [Hash, nil] Output format configuration for structured output
      attr_accessor :output_format

      # @return [String, nil] Current working directory
      attr_accessor :cwd

      # @return [Array<String>] Additional directories the agent can access
      attr_accessor :add_dirs

      # @return [Hash<String, String>] Environment variables
      attr_accessor :env

      # @return [Proc, nil] Custom permission callback
      #   Called when Claude wants to use a tool that isn't auto-approved.
      #   Receives (tool_name, input, context) and returns PermissionResult
      attr_accessor :can_use_tool

      # @return [Hash<Symbol, Array<HookMatcher>>] Hook configurations
      attr_accessor :hooks

      # @return [String, nil] User identifier
      attr_accessor :user

      # @return [Boolean] Include partial message streaming events
      attr_accessor :include_partial_messages

      # @return [Hash<String, AgentDefinition>] Programmatically defined subagents
      attr_accessor :agents

      # @return [Array<Symbol>] Setting sources to load (:user, :project, :local)
      attr_accessor :setting_sources

      # @return [Hash, nil] Sandbox configuration
      attr_accessor :sandbox

      # @return [Float, nil] Maximum budget in USD
      attr_accessor :max_budget_usd

      # @return [Integer, nil] Maximum thinking tokens
      attr_accessor :max_thinking_tokens

      # @return [Proc, nil] Callback for stderr output
      attr_accessor :stderr

      # @return [Integer, nil] Maximum buffer size for CLI stdout
      attr_accessor :max_buffer_size

      # @return [Boolean] Enable file change tracking for rewinding
      attr_accessor :enable_file_checkpointing

      # @return [Hash<String, String>] Additional CLI arguments
      attr_accessor :extra_args

      def initialize(
        allowed_tools: [],
        disallowed_tools: [],
        system_prompt: nil,
        mcp_servers: {},
        permission_mode: :default,
        continue_conversation: false,
        resume: nil,
        fork_session: false,
        max_turns: nil,
        model: nil,
        output_format: nil,
        cwd: nil,
        add_dirs: [],
        env: {},
        can_use_tool: nil,
        hooks: {},
        user: nil,
        include_partial_messages: false,
        agents: {},
        setting_sources: nil,
        sandbox: nil,
        max_budget_usd: nil,
        max_thinking_tokens: nil,
        stderr: nil,
        max_buffer_size: nil,
        enable_file_checkpointing: false,
        extra_args: {}
      )
        @allowed_tools = allowed_tools
        @disallowed_tools = disallowed_tools
        @system_prompt = system_prompt
        @mcp_servers = mcp_servers
        @permission_mode = permission_mode
        @continue_conversation = continue_conversation
        @resume = resume
        @fork_session = fork_session
        @max_turns = max_turns
        @model = model
        @output_format = output_format
        @cwd = cwd
        @add_dirs = add_dirs
        @env = env
        @can_use_tool = can_use_tool
        @hooks = normalize_hooks(hooks)
        @user = user
        @include_partial_messages = include_partial_messages
        @agents = agents
        @setting_sources = setting_sources
        @sandbox = sandbox
        @max_budget_usd = max_budget_usd
        @max_thinking_tokens = max_thinking_tokens
        @stderr = stderr
        @max_buffer_size = max_buffer_size
        @enable_file_checkpointing = enable_file_checkpointing
        @extra_args = extra_args
      end

      # Check if a specific tool is allowed
      #
      # @param tool_name [String] Name of the tool
      # @return [Boolean]
      def tool_allowed?(tool_name)
        return false if disallowed_tools.include?(tool_name)
        return true if allowed_tools.empty?

        allowed_tools.include?(tool_name)
      end

      # Get the effective system prompt
      #
      # @return [String, nil]
      def effective_system_prompt
        case system_prompt
        when String
          system_prompt
        when Hash
          if system_prompt[:type] == :preset && system_prompt[:preset] == :claude_code
            base = claude_code_system_prompt
            system_prompt[:append] ? "#{base}\n\n#{system_prompt[:append]}" : base
          else
            system_prompt.to_s
          end
        else
          nil
        end
      end

      # Convert to hash for serialization
      #
      # @return [Hash]
      def to_h
        {
          allowed_tools: allowed_tools,
          disallowed_tools: disallowed_tools,
          system_prompt: system_prompt,
          mcp_servers: mcp_servers.transform_values(&:to_h),
          permission_mode: permission_mode,
          continue_conversation: continue_conversation,
          resume: resume,
          fork_session: fork_session,
          max_turns: max_turns,
          model: model,
          output_format: output_format,
          cwd: cwd,
          add_dirs: add_dirs,
          env: env,
          user: user,
          include_partial_messages: include_partial_messages,
          agents: agents.transform_values(&:to_h),
          setting_sources: setting_sources,
          sandbox: sandbox,
          max_budget_usd: max_budget_usd,
          max_thinking_tokens: max_thinking_tokens,
          enable_file_checkpointing: enable_file_checkpointing,
          extra_args: extra_args
        }.compact
      end

      private

      def normalize_hooks(hooks)
        return {} if hooks.nil? || hooks.empty?

        hooks.transform_keys do |key|
          case key
          when Symbol then key
          when String then key.to_sym
          else key
          end
        end
      end

      def claude_code_system_prompt
        # This would be loaded from Claude Code's actual system prompt
        # For now, return a placeholder
        <<~PROMPT
          You are Claude, an AI assistant created by Anthropic.
          You have access to a set of tools to help users with software engineering tasks.
        PROMPT
      end
    end
  end
end
