# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    class Options
      # Schema for introspection (agent-native)
      SCHEMA = {
        prompt: { type: String, required: true },
        allowed_tools: { type: Array, default: [] },
        disallowed_tools: { type: Array, default: [] },
        permission_mode: { type: Symbol, default: :default, enum: Permissions::MODES },
        model: { type: Symbol, default: nil },
        max_turns: { type: Integer, default: nil },
        cwd: { type: String, default: nil },
        resume: { type: String, default: nil },
        system_prompt: { type: String, default: nil },
        mcp_servers: { type: Hash, default: {} },
        hooks: { type: Hash, default: {} },
        can_use_tool: { type: Proc, default: nil },
        env: { type: Hash, default: {} },
        timeout: { type: Integer, default: nil }
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

      # Fluent builder methods (match Chat's with_* pattern)
      def with_tools(*tools)
        @allowed_tools = tools.flatten.map(&:to_s)
        self
      end

      def without_tools(*tools)
        @disallowed_tools = tools.flatten.map(&:to_s)
        self
      end

      def with_model(model)
        @model = model.to_sym
        self
      end

      def with_permission_mode(mode)
        @permission_mode = mode.to_sym
        self
      end

      def with_cwd(path)
        @cwd = File.expand_path(path)
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

      def with_timeout(seconds)
        @timeout = seconds
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
        # Convert to CLI arguments
        {
          cwd: @cwd,
          model: @model,
          max_turns: @max_turns,
          permission_mode: @permission_mode,
          resume: @resume,
          system_prompt: @system_prompt,
          allowed_tools: @allowed_tools,
          disallowed_tools: @disallowed_tools
        }.compact
      end
    end
  end
end
