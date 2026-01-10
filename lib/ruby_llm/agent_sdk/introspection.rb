# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # Agent-native introspection and discovery
    #
    # Provides self-describing capabilities for the SDK, allowing
    # agents to discover available options, tools, hooks, and more.
    # This enables truly agent-native applications.
    #
    # @example Discover all capabilities
    #   schema = Introspection.schema
    #   puts schema[:options]      # All configuration options
    #   puts schema[:hooks]        # Available hook events
    #   puts schema[:tools]        # Built-in tool names
    #
    # @example Agent prompt generation
    #   prompt = Introspection.generate_capabilities_prompt(client)
    #   # Returns a prompt describing all capabilities for the agent
    module Introspection
      # Built-in Claude tools
      BUILT_IN_TOOLS = %w[
        Bash
        Read
        Write
        Edit
        MultiEdit
        Glob
        Grep
        LS
        Task
        WebFetch
        WebSearch
        TodoRead
        TodoWrite
        NotebookRead
        NotebookEdit
        AskFollowupQuestion
      ].freeze

      # Available models
      MODELS = %i[opus sonnet haiku].freeze

      # Hook events with descriptions
      HOOK_EVENTS = {
        pre_tool_use: 'Before a tool is executed',
        post_tool_use: 'After a tool completes successfully',
        stop: 'When the agent stops',
        subagent_stop: 'When a subagent completes',
        session_start: 'When a new session begins',
        session_end: 'When a session ends',
        user_prompt_submit: 'When user submits a prompt',
        pre_compact: 'Before context compaction',
        notification: 'On agent notifications'
      }.freeze

      # Permission modes with descriptions
      PERMISSION_MODES = {
        default: 'Standard permission behavior',
        accept_edits: 'Auto-accept file edits and filesystem operations',
        dont_ask: 'Skip approval prompts - auto-deny unless allowed',
        bypass_permissions: 'Bypass all permission checks (use with caution)',
        plan: 'Planning mode - analyze but do not execute'
      }.freeze

      class << self
        # Get full SDK schema
        #
        # @return [Hash]
        def schema
          {
            version: VERSION,
            options: options_schema,
            hooks: hooks_schema,
            permissions: permissions_schema,
            tools: tools_schema,
            models: MODELS,
            mcp_transports: MCP::TRANSPORTS
          }
        end

        # Get options schema with types and defaults
        #
        # @return [Hash]
        def options_schema
          Options::SCHEMA
        end

        # Get hooks schema
        #
        # @return [Hash]
        def hooks_schema
          {
            events: HOOK_EVENTS,
            decisions: Hooks::DECISIONS,
            result_fields: %i[decision payload reason]
          }
        end

        # Get permissions schema
        #
        # @return [Hash]
        def permissions_schema
          {
            modes: PERMISSION_MODES,
            accept_edits_tools: PermissionMode::ACCEPT_EDITS_TOOLS,
            accept_edits_commands: PermissionMode::ACCEPT_EDITS_COMMANDS
          }
        end

        # Get tools schema
        #
        # @return [Hash]
        def tools_schema
          {
            built_in: BUILT_IN_TOOLS,
            custom_schema: {
              name: { type: String, required: true },
              description: { type: String, required: true },
              input_schema: { type: Hash, required: false }
            }
          }
        end

        # Generate a capabilities prompt for an agent
        #
        # @param client [Client, nil] Optional client to include custom tools
        # @return [String]
        def generate_capabilities_prompt(client = nil)
          parts = []

          parts << '# Agent SDK Capabilities'
          parts << ''
          parts << '## Configuration Options'
          parts << ''
          Options::SCHEMA.each do |name, config|
            type_str = config[:type].is_a?(Symbol) ? config[:type] : config[:type].name
            default_str = config[:default].nil? ? 'nil' : config[:default].inspect
            parts << "- **#{name}** (#{type_str}, default: #{default_str}): #{config[:description]}"
          end

          parts << ''
          parts << '## Permission Modes'
          parts << ''
          PERMISSION_MODES.each do |mode, desc|
            parts << "- **#{mode}**: #{desc}"
          end

          parts << ''
          parts << '## Available Hooks'
          parts << ''
          HOOK_EVENTS.each do |event, desc|
            parts << "- **#{event}**: #{desc}"
          end

          parts << ''
          parts << '## Built-in Tools'
          parts << ''
          parts << BUILT_IN_TOOLS.join(', ')

          if client&.instance_variable_get(:@tool_registry)&.size&.positive?
            registry = client.instance_variable_get(:@tool_registry)
            parts << ''
            parts << '## Custom Tools'
            parts << ''
            registry.each do |tool|
              parts << "- **#{tool.name}**: #{tool.description}"
            end
          end

          parts << ''
          parts << '## MCP Transport Types'
          parts << ''
          parts << MCP::TRANSPORTS.map(&:to_s).join(', ')

          parts.join("\n")
        end

        # Validate a configuration hash
        #
        # @param config [Hash] Configuration to validate
        # @return [Array<String>] List of validation errors
        def validate_config(config)
          errors = []

          config.each do |key, value|
            schema_entry = Options::SCHEMA[key.to_sym]

            if schema_entry.nil?
              errors << "Unknown option: #{key}"
              next
            end

            expected_type = schema_entry[:type]
            next if value.nil? # Allow nil values

            case expected_type
            when :boolean
              unless [true, false].include?(value)
                errors << "#{key} must be a boolean"
              end
            when Class
              unless value.is_a?(expected_type)
                errors << "#{key} must be a #{expected_type.name}"
              end
            end
          end

          # Check for permission mode validity
          if config[:permission_mode] && !PermissionMode.valid?(config[:permission_mode])
            errors << "Invalid permission_mode: #{config[:permission_mode]}"
          end

          # Check for model validity
          if config[:model] && !MODELS.include?(config[:model]&.to_sym)
            errors << "Invalid model: #{config[:model]}. Must be one of: #{MODELS.join(', ')}"
          end

          errors
        end

        # Check if a capability is available
        #
        # @param capability [Symbol] Capability to check
        # @return [Boolean]
        def supports?(capability)
          case capability
          when :streaming then true
          when :hooks then true
          when :mcp then true
          when :custom_tools then true
          when :sessions then true
          when :multi_turn then true
          when :permission_modes then true
          when :subagents then true
          else false
          end
        end
      end
    end
  end
end
