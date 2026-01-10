# frozen_string_literal: true

require 'open3'
require 'timeout'

module RubyLLM
  class Agent
    module Tools
      # Execute shell commands
      #
      # Example:
      #   chat.with_tool(RubyLLM::Agent::Tools::Bash)
      #   chat.ask "List all Ruby files in the current directory"
      class Bash < RubyLLM::Tool
        description 'Execute a shell command and return its output'

        param :command, desc: 'The shell command to execute'
        param :timeout, type: 'integer', desc: 'Timeout in seconds (default: 30)', required: false

        # Commands that are blocked for safety
        BLOCKED_PATTERNS = [
          /\brm\s+-rf\s+[\/~]/i,    # rm -rf with root or home
          /\bmkfs\b/i,               # filesystem formatting
          /\bdd\b.*\bof=/i,          # dd to device
          />\s*\/dev\/sd/i,          # writing to block devices
          /\bshutdown\b/i,           # shutdown
          /\breboot\b/i              # reboot
        ].freeze

        def execute(command:, timeout: 30)
          # Safety check
          BLOCKED_PATTERNS.each do |pattern|
            if command.match?(pattern)
              return { error: "Command blocked for safety: #{command}" }
            end
          end

          stdout, stderr, status = nil
          Timeout.timeout(timeout) do
            stdout, stderr, status = Open3.capture3(command)
          end

          output = []
          output << stdout unless stdout.empty?
          output << "STDERR: #{stderr}" unless stderr.empty?
          output << "Exit code: #{status.exitstatus}" unless status.success?

          output.empty? ? 'Command completed successfully (no output)' : output.join("\n")
        rescue Timeout::Error
          { error: "Command timed out after #{timeout} seconds" }
        rescue StandardError => e
          { error: e.message }
        end
      end
    end
  end
end
