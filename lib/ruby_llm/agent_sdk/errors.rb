# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # Base error class with error codes for programmatic handling
    class Error < StandardError
      attr_reader :error_code

      def initialize(message, error_code: :unknown)
        @error_code = error_code
        super(message)
      end

      def to_h
        { code: error_code, message: message }
      end
    end

    # Claude CLI not found in PATH
    class CLINotFoundError < Error
      def initialize(message = 'Claude CLI not found')
        super(message, error_code: :cli_not_found)
      end
    end

    # CLI process exited with non-zero status
    class ProcessError < Error
      attr_reader :exit_code, :stderr

      def initialize(message, exit_code: nil, stderr: nil, error_code: :process_error)
        @exit_code = exit_code
        @stderr = stderr
        super(message, error_code: error_code)
      end

      def to_h
        super.merge(exit_code: exit_code, stderr: stderr)
      end
    end

    # Failed to parse JSON from CLI output
    class JSONDecodeError < Error
      attr_reader :line, :original_error

      def initialize(message, line: nil, original_error: nil)
        @line = line
        @original_error = original_error
        super(message, error_code: :json_decode_error)
      end

      def to_h
        super.merge(line: line&.slice(0, 200))
      end
    end

    # Operation timed out
    class TimeoutError < Error
      def initialize(message = 'Operation timed out')
        super(message, error_code: :timeout)
      end
    end

    # Operation was aborted
    class AbortError < Error
      def initialize(message = 'Operation aborted')
        super(message, error_code: :aborted)
      end
    end

    # Permission denied for tool use
    class PermissionDeniedError < Error
      attr_reader :tool_name, :reason

      def initialize(message, tool_name: nil, reason: nil)
        @tool_name = tool_name
        @reason = reason
        super(message, error_code: :permission_denied)
      end

      def to_h
        super.merge(tool_name: tool_name, reason: reason)
      end
    end

    # Security violation detected
    class SecurityError < Error
      def initialize(message)
        super(message, error_code: :security_error)
      end
    end

    # Invalid configuration
    class ConfigurationError < Error
      def initialize(message)
        super(message, error_code: :configuration_error)
      end
    end
  end
end
