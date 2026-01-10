# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    module Permissions
      # Permission mode constants (Ruby symbols)
      DEFAULT = :default
      ACCEPT_EDITS = :accept_edits
      DONT_ASK = :dont_ask
      BYPASS = :bypass_permissions
      PLAN = :plan
      DELEGATE = :delegate

      MODES = [DEFAULT, ACCEPT_EDITS, DONT_ASK, BYPASS, PLAN, DELEGATE].freeze

      # CLI format mapping (camelCase required by claude CLI)
      CLI_MODES = {
        default: 'default',
        accept_edits: 'acceptEdits',
        dont_ask: 'dontAsk',
        bypass_permissions: 'bypassPermissions',
        plan: 'plan',
        delegate: 'delegate'
      }.freeze

      # Tools auto-approved in accept_edits mode
      ACCEPT_EDITS_TOOLS = %w[Edit Write].freeze
      ACCEPT_EDITS_COMMANDS = %w[mkdir touch rm mv cp].freeze

      class << self
        def valid?(mode)
          MODES.include?(mode.to_sym)
        end

        def to_cli_format(mode)
          CLI_MODES[mode.to_sym] || mode.to_s
        end

        def auto_approve?(mode, tool_name, tool_input = {})
          case mode.to_sym
          when BYPASS then true
          when ACCEPT_EDITS then accept_edits_auto_approve?(tool_name, tool_input)
          when DONT_ASK then nil # Defer to callback
          when PLAN then false   # Never auto-approve in plan mode
          else nil
          end
        end

        private

        def accept_edits_auto_approve?(tool_name, tool_input)
          return true if ACCEPT_EDITS_TOOLS.include?(tool_name)

          if tool_name == 'Bash'
            cmd = (tool_input[:command] || tool_input['command'] || '').split.first
            return true if cmd && ACCEPT_EDITS_COMMANDS.include?(cmd)
          end

          nil
        end
      end

      # Result from permission check
      Result = Struct.new(:behavior, :updated_input, :message, keyword_init: true) do
        def allow? = behavior == :allow
        def deny? = behavior == :deny
        def ask? = behavior == :ask

        def self.allow(input = nil) = new(behavior: :allow, updated_input: input)
        def self.deny(message = nil) = new(behavior: :deny, message: message)
        def self.ask = new(behavior: :ask)
      end
    end
  end
end
