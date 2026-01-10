# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    module Introspection
      # All 17 built-in tools (agent-native discovery)
      BUILTIN_TOOLS = %w[
        Agent AskUserQuestion Bash Edit ExitPlanMode EnterPlanMode
        Glob Grep KillShell LS NotebookEdit Read TaskOutput
        TodoWrite WebFetch WebSearch Write
      ].freeze

      class << self
        def cli_available?
          system('which claude > /dev/null 2>&1')
        end

        def cli_version
          version = `claude --version 2>/dev/null`.strip
          version.empty? ? nil : version
        rescue StandardError
          nil
        end

        def requirements_met?
          {
            cli_available: cli_available?,
            cli_version: cli_version,
            oj_available: Stream.oj_available?
          }
        end

        def builtin_tools
          BUILTIN_TOOLS
        end

        def hook_events
          Hooks::EVENTS
        end

        def permission_modes
          Permissions::MODES
        end

        def options_schema
          Options::SCHEMA
        end

        # List all available tools (built-in + custom)
        def available_tools(custom_tools: [])
          BUILTIN_TOOLS + custom_tools.map { |t| t.respond_to?(:name) ? t.name : t.to_s }
        end
      end
    end
  end
end
