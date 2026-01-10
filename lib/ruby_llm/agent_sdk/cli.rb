# frozen_string_literal: true

require 'open3'
require 'timeout'

module RubyLLM
  module AgentSDK
    class CLI
      COMMAND = 'claude'
      DEFAULT_ARGS = ['--print', '--output-format', 'stream-json', '--verbose'].freeze

      def initialize(options = {})
        @options = options
        @cli_path = options[:cli_path] || COMMAND
        @pid = nil
        @mutex = Mutex.new
        @shutdown = false
      end

      # Stream messages from CLI - SAFE array-based spawning
      def stream(prompt, &block)
        args = build_args(prompt)
        stderr_lines = []

        # CRITICAL: Use array form to prevent command injection
        Open3.popen3(@cli_path, *args) do |stdin, stdout, stderr, wait_thread|
          @mutex.synchronize { @pid = wait_thread.pid }
          stdin.close

          # Collect stderr in background thread
          stderr_thread = Thread.new do
            Thread.current.report_on_exception = false
            stderr.each_line { |line| stderr_lines << line.strip }
          rescue IOError
            # Stream closed, expected during cleanup
          end

          # Stream stdout with cancellation support
          stream_with_cancellation(stdout, &block)

          stderr_thread.join
          handle_exit(wait_thread.value, stderr_lines)
        end
      rescue Errno::ENOENT
        raise CLINotFoundError, 'Claude CLI not found. Install from: npm install -g @anthropic-ai/claude-code'
      ensure
        @mutex.synchronize { @pid = nil }
      end

      def abort
        @shutdown = true
        kill_process
      end

      private

      def stream_with_cancellation(stdout, &block)
        buffer = String.new(capacity: 16_384) # Pre-allocate buffer

        until stdout.eof? || @shutdown
          ready = IO.select([stdout], nil, nil, 0.1)
          next unless ready

          begin
            data = stdout.read_nonblock(4096)
            buffer << data

            while (idx = buffer.index("\n"))
              line = buffer.slice!(0, idx + 1).strip
              block.call(line) unless line.empty?
            end
          rescue IO::WaitReadable
            # No data yet
          rescue EOFError
            break
          end
        end

        # Process remaining buffer
        block.call(buffer.strip) unless buffer.strip.empty?
      end

      def build_args(prompt)
        args = DEFAULT_ARGS.dup

        # Add options - all validated, no shell interpolation
        args.push('--cwd', @options[:cwd]) if @options[:cwd]
        args.push('--model', @options[:model].to_s) if @options[:model]
        args.push('--max-turns', @options[:max_turns].to_s) if @options[:max_turns]
        if @options[:permission_mode]
          cli_mode = Permissions.to_cli_format(@options[:permission_mode])
          args.push('--permission-mode', cli_mode)
        end
        args.push('--resume', @options[:resume]) if @options[:resume]
        args.push('--system-prompt', @options[:system_prompt]) if @options[:system_prompt]
        args.push('--fork-session') if @options[:fork_session]

        # Allowed/disallowed tools
        if @options[:allowed_tools]&.any?
          @options[:allowed_tools].each { |t| args.push('--allowed-tool', t.to_s) }
        end
        if @options[:disallowed_tools]&.any?
          @options[:disallowed_tools].each { |t| args.push('--disallowed-tool', t.to_s) }
        end

        # Prompt is passed as final positional argument (safe - no shell expansion)
        args.push(prompt)

        args
      end

      def kill_process
        pid = @mutex.synchronize { @pid }
        return unless pid

        begin
          Process.kill('TERM', pid)
          Timeout.timeout(5) { Process.wait(pid) }
        rescue Timeout::Error
          begin
            Process.kill('KILL', pid)
          rescue Errno::ESRCH
            # Already gone
          end
          begin
            Process.wait(pid)
          rescue Errno::ECHILD
            # Already reaped
          end
        rescue Errno::ESRCH, Errno::ECHILD
          # Already gone
        end
      end

      def handle_exit(status, stderr_lines)
        return if status.success?

        raise ProcessError.new(
          "CLI exited with code #{status.exitstatus}",
          exit_code: status.exitstatus,
          stderr: stderr_lines.join("\n"),
          error_code: :cli_error
        )
      end
    end
  end
end
