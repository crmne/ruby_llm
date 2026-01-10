# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # Configuration options for Agent SDK sessions.
    #
    # There are two ways to configure options:
    #
    # == Preferred: Constructor keyword arguments
    #
    # The simplest approach is to pass all options directly to the constructor:
    #
    #   options = Options.new(
    #     prompt: "Analyze this codebase",
    #     model: "claude-sonnet-4-20250514",
    #     cwd: "/path/to/project",
    #     max_turns: 5,
    #     permission_mode: :plan
    #   )
    #
    # == Alternative: Fluent builder pattern
    #
    # For method chaining scenarios or when building options incrementally,
    # use the with_* methods:
    #
    #   options = Options.new(prompt: "Analyze this codebase")
    #     .with_model("claude-sonnet-4-20250514")
    #     .with_cwd("/path/to/project")
    #     .with_max_turns(5)
    #     .with_permission_mode(:plan)
    #
    # The fluent API is useful when:
    # - Building options conditionally across multiple code paths
    # - Matching RubyLLM::Chat's with_* pattern for consistency
    # - Porting code from the TypeScript SDK
    #
    # @see Agent#run for executing with these options
    class Options
      # Schema for introspection (agent-native) - mirrors TypeScript SDK Options
      SCHEMA = {
        # Core
        prompt: { type: String, required: true },
        cwd: { type: String, default: nil },

        # Model configuration
        model: { type: String, default: nil },
        fallback_model: { type: String, default: nil },
        max_turns: { type: Integer, default: nil },
        max_thinking_tokens: { type: Integer, default: nil },
        max_budget_usd: { type: Float, default: nil },

        # Permission & security
        permission_mode: { type: Symbol, default: :default, enum: Permissions::MODES },
        allow_dangerously_skip_permissions: { type: :boolean, default: false },

        # Tools
        tools: { type: Array, default: nil }, # nil = all tools, or array of names, or { type: 'preset', preset: 'claude_code' }
        allowed_tools: { type: Array, default: [] },
        disallowed_tools: { type: Array, default: [] },

        # Session management
        resume: { type: String, default: nil },
        resume_session_at: { type: String, default: nil },
        fork_session: { type: :boolean, default: false },
        continue: { type: :boolean, default: false },

        # System prompt
        system_prompt: { type: [String, Hash], default: nil }, # String or { type: 'preset', preset: 'claude_code', append: '...' }

        # MCP & Hooks
        mcp_servers: { type: Hash, default: {} },
        hooks: { type: Hash, default: {} },
        can_use_tool: { type: Proc, default: nil },

        # Directories & Settings
        additional_directories: { type: Array, default: [] },
        setting_sources: { type: Array, default: [] }, # [:user, :project, :local]

        # Streaming & Output
        include_partial_messages: { type: :boolean, default: false },
        output_format: { type: Hash, default: nil }, # { type: 'json_schema', schema: {...} }
        stderr: { type: Proc, default: nil },

        # Advanced
        env: { type: Hash, default: {} },
        timeout: { type: Integer, default: nil },
        cli_path: { type: String, default: nil },
        agents: { type: Hash, default: {} }, # Programmatic subagent definitions
        plugins: { type: Array, default: [] }, # [{ type: 'local', path: '...' }]
        betas: { type: Array, default: [] }, # ['context-1m-2025-08-07']
        sandbox: { type: Hash, default: nil },
        strict_mcp_config: { type: :boolean, default: false },
        enable_file_checkpointing: { type: :boolean, default: false },
        extra_args: { type: Hash, default: {} }
      }.freeze

      attr_accessor(*SCHEMA.keys)

      def initialize(**attrs)
        SCHEMA.each do |key, config|
          default_value = config[:default]
          # Deep dup mutable defaults
          default_value = default_value.dup if default_value.is_a?(Hash) || default_value.is_a?(Array)
          instance_variable_set(:"@#{key}", attrs.fetch(key, default_value))
        end
      end

      # Fluent builder methods for method chaining.
      #
      # These methods return +self+ to enable chaining. While constructor kwargs
      # are preferred for simple cases, these are useful for:
      # - Conditional option building across multiple code paths
      # - Consistency with RubyLLM::Chat's fluent API
      # - Incremental configuration building
      #
      # @note Some methods provide conveniences beyond simple assignment:
      #   - with_cwd/with_cli_path expand paths via File.expand_path
      #   - with_tools/without_tools flatten arrays and convert to strings
      #   - with_output_format wraps the schema in the expected structure

      def with_tools(*tools)
        @allowed_tools = tools.flatten.map(&:to_s)
        self
      end

      def without_tools(*tools)
        @disallowed_tools = tools.flatten.map(&:to_s)
        self
      end

      def with_model(model)
        @model = model.to_s
        self
      end

      def with_fallback_model(model)
        @fallback_model = model.to_s
        self
      end

      def with_permission_mode(mode)
        @permission_mode = mode.to_sym
        self
      end

      def with_dangerous_permissions(enabled = true)
        @allow_dangerously_skip_permissions = enabled
        self
      end

      def with_cwd(path)
        @cwd = File.expand_path(path)
        self
      end

      def with_additional_directories(*dirs)
        @additional_directories = dirs.flatten.map { |d| File.expand_path(d) }
        self
      end

      def with_hooks(hooks)
        @hooks = hooks
        self
      end

      def with_mcp_server(name, server)
        @mcp_servers[name.to_sym] = server
        self
      end

      def with_system_prompt(prompt)
        @system_prompt = prompt
        self
      end

      def with_max_turns(turns)
        @max_turns = turns
        self
      end

      def with_max_thinking_tokens(tokens)
        @max_thinking_tokens = tokens
        self
      end

      def with_max_budget_usd(budget)
        @max_budget_usd = budget.to_f
        self
      end

      def with_timeout(seconds)
        @timeout = seconds
        self
      end

      def with_cli_path(path)
        @cli_path = File.expand_path(path)
        self
      end

      def with_fork_session(enabled = true)
        @fork_session = enabled
        self
      end

      def with_continue(enabled = true)
        @continue = enabled
        self
      end

      def with_resume(session_id, at: nil)
        @resume = session_id
        @resume_session_at = at
        self
      end

      def with_output_format(schema)
        @output_format = { type: 'json_schema', schema: schema }
        self
      end

      def with_partial_messages(enabled = true)
        @include_partial_messages = enabled
        self
      end

      def with_agents(agents)
        @agents = agents
        self
      end

      def with_plugins(*plugins)
        @plugins = plugins.flatten
        self
      end

      def with_betas(*betas)
        @betas = betas.flatten
        self
      end

      def with_sandbox(config)
        @sandbox = config
        self
      end

      def with_setting_sources(*sources)
        @setting_sources = sources.flatten.map(&:to_sym)
        self
      end

      def with_file_checkpointing(enabled = true)
        @enable_file_checkpointing = enabled
        self
      end

      def with_stderr(&block)
        @stderr = block
        self
      end

      # Class methods for introspection (agent-native)
      class << self
        def schema
          SCHEMA
        end

        def attribute_names
          SCHEMA.keys
        end

        def build
          new
        end
      end

      def to_h
        SCHEMA.keys.each_with_object({}) do |key, hash|
          value = send(key)
          hash[key] = value unless value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
      end

      def to_cli_args
        args = {
          cwd: @cwd,
          model: @model,
          max_turns: @max_turns,
          permission_mode: @permission_mode,
          resume: @resume,
          system_prompt: @system_prompt,
          allowed_tools: @allowed_tools,
          disallowed_tools: @disallowed_tools,
          cli_path: @cli_path,
          fork_session: @fork_session,
          continue: @continue,
          additional_directories: @additional_directories,
          max_thinking_tokens: @max_thinking_tokens,
          max_budget_usd: @max_budget_usd,
          fallback_model: @fallback_model,
          include_partial_messages: @include_partial_messages,
          resume_session_at: @resume_session_at,
          enable_file_checkpointing: @enable_file_checkpointing,
          betas: @betas,
          output_format: @output_format
        }.compact

        # Remove empty arrays
        args.delete_if { |_, v| v.is_a?(Array) && v.empty? }
        args
      end
    end
  end
end
