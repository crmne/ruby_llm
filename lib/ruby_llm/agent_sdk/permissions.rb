# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # Permission system for controlling tool execution
    #
    # Permission modes provide global control over how Claude uses tools.
    # They are evaluated after hooks and permission rules.
    module Permissions
      # Permission mode constants
      DEFAULT = :default
      ACCEPT_EDITS = :accept_edits
      DONT_ASK = :dont_ask
      BYPASS = :bypass_permissions
      PLAN = :plan

      # All valid permission modes
      MODES = [DEFAULT, ACCEPT_EDITS, DONT_ASK, BYPASS, PLAN].freeze

      # Tools auto-approved in accept_edits mode
      ACCEPT_EDITS_TOOLS = %w[Edit Write].freeze

      # Bash commands auto-approved in accept_edits mode
      ACCEPT_EDITS_COMMANDS = %w[mkdir touch rm mv cp].freeze

      class << self
        # Check if a permission mode is valid
        #
        # @param mode [Symbol, String] Permission mode to check
        # @return [Boolean]
        def valid?(mode)
          MODES.include?(mode.to_sym)
        end

        # Determine if a tool should be auto-approved based on mode
        #
        # @param mode [Symbol] Current permission mode
        # @param tool_name [String] Name of the tool
        # @param tool_input [Hash] Tool input parameters
        # @return [Boolean, nil] true to approve, false to deny, nil to continue
        def auto_approve?(mode, tool_name, tool_input = {})
          case mode.to_sym
          when BYPASS
            true
          when ACCEPT_EDITS
            accept_edits_auto_approve?(tool_name, tool_input)
          when DONT_ASK
            nil # Defer to callback
          when PLAN
            false # Never auto-approve in plan mode
          else
            nil
          end
        end

        private

        def accept_edits_auto_approve?(tool_name, tool_input)
          return true if ACCEPT_EDITS_TOOLS.include?(tool_name)

          if tool_name == 'Bash'
            command = tool_input[:command] || tool_input['command'] || ''
            first_cmd = command.to_s.split.first
            return true if first_cmd && ACCEPT_EDITS_COMMANDS.include?(first_cmd)
          end

          nil
        end
      end

      # Result from a permission check
      #
      # @example Allow with modified input
      #   Result.allow(sanitized_input)
      #
      # @example Deny with message
      #   Result.deny("Dangerous command blocked")
      Result = Struct.new(:behavior, :updated_input, :message, keyword_init: true) do
        def allow? = behavior == :allow
        def deny? = behavior == :deny
        def ask? = behavior == :ask

        def self.allow(input = nil)
          new(behavior: :allow, updated_input: input)
        end

        def self.deny(message = nil)
          new(behavior: :deny, message: message)
        end

        def self.ask
          new(behavior: :ask)
        end
      end
    end
  end
end
