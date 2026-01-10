# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # Permission modes for controlling tool execution
    #
    # Permission modes provide global control over how Claude uses tools.
    # They are evaluated after hooks and permission rules.
    #
    module PermissionMode
      # Standard permission behavior - no auto-approvals
      # Unmatched tools trigger the can_use_tool callback
      DEFAULT = :default

      # Auto-accept file edits and filesystem operations
      # mkdir, touch, rm, mv, cp are automatically approved
      ACCEPT_EDITS = :accept_edits

      # Skip approval prompts - auto-deny tools unless allowed by rules
      DONT_ASK = :dont_ask

      # Bypass all permission checks (use with caution)
      # All tools run without permission prompts
      BYPASS_PERMISSIONS = :bypass_permissions

      # Planning mode - analyze but don't execute
      PLAN = :plan

      ALL = [DEFAULT, ACCEPT_EDITS, DONT_ASK, BYPASS_PERMISSIONS, PLAN].freeze

      # Tools automatically approved in accept_edits mode
      ACCEPT_EDITS_TOOLS = %w[Edit Write].freeze

      # Filesystem commands approved in accept_edits mode
      ACCEPT_EDITS_COMMANDS = %w[mkdir touch rm mv cp].freeze

      class << self
        # Check if a mode is valid
        #
        # @param mode [Symbol] Permission mode
        # @return [Boolean]
        def valid?(mode)
          ALL.include?(mode)
        end

        # Determine if a tool should be auto-approved based on mode
        #
        # @param mode [Symbol] Current permission mode
        # @param tool_name [String] Name of the tool
        # @param tool_input [Hash] Tool input parameters
        # @return [Boolean, nil] true to approve, false to deny, nil to continue to next check
        def auto_approve?(mode, tool_name, tool_input = {})
          case mode
          when BYPASS_PERMISSIONS
            true
          when ACCEPT_EDITS
            auto_approve_for_accept_edits?(tool_name, tool_input)
          when DONT_ASK
            # Auto-deny unless explicitly allowed by rules
            nil
          when PLAN
            # Planning mode - don't execute anything
            false
          else
            nil
          end
        end

        private

        def auto_approve_for_accept_edits?(tool_name, tool_input)
          return true if ACCEPT_EDITS_TOOLS.include?(tool_name)

          if tool_name == 'Bash'
            command = tool_input[:command] || tool_input['command'] || ''
            first_cmd = command.split(/\s+/).first
            return true if first_cmd && ACCEPT_EDITS_COMMANDS.include?(first_cmd)
          end

          nil
        end
      end
    end
  end
end
