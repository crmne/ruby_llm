# frozen_string_literal: true

require 'open3'
require 'timeout'
require 'json'

module RubyLLM
  module AgentSDK
    class CLI
      COMMAND = 'claude'
      DEFAULT_ARGS = ['--print', '--output-format', 'stream-json', '--verbose'].freeze

      attr_reader :options

      def initialize(options = {})
        @options = options
        @cli_path = options[:cli_path] || COMMAND
        @pid = nil
        @mutex = Mutex.new
        @shutdown = false
        @stderr_callback = options[:stderr]
      end

      # Stream messages from CLI - SAFE array-based spawning
      def stream(prompt, &block)
        args = build_args(prompt)
        stderr_lines = []

        env = build_env

        # CRITICAL: Use array form to prevent command injection
        Open3.popen3(env, @cli_path, *args) do |stdin, stdout, stderr, wait_thread|
          @mutex.synchronize { @pid = wait_thread.pid }
          stdin.close

          # Collect stderr in background thread
          stderr_thread = Thread.new do
            Thread.current.report_on_exception = false
            stderr.each_line do |line|
              stripped = line.strip
              stderr_lines << stripped
              @stderr_callback&.call(stripped)
            end
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

      def build_env
        env = {}
        # Pass through custom env vars
        @options[:env]&.each do |key, value|
          env[key.to_s] = value.to_s
        end
        env
      end

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

        # Core options
        args.push('--cwd', @options[:cwd]) if @options[:cwd]

        # Model configuration
        args.push('--model', @options[:model].to_s) if @options[:model]
        args.push('--fallback-model', @options[:fallback_model].to_s) if @options[:fallback_model]
        args.push('--max-turns', @options[:max_turns].to_s) if @options[:max_turns]
        args.push('--max-thinking-tokens', @options[:max_thinking_tokens].to_s) if @options[:max_thinking_tokens]
        args.push('--max-budget-usd', @options[:max_budget_usd].to_s) if @options[:max_budget_usd]

        # Permission & security
        if @options[:permission_mode]
          cli_mode = Permissions.to_cli_format(@options[:permission_mode])
          args.push('--permission-mode', cli_mode)
        end
        args.push('--dangerously-skip-permissions') if @options[:allow_dangerously_skip_permissions]

        # Session management
        args.push('--resume', @options[:resume]) if @options[:resume]
        args.push('--resume-session-at', @options[:resume_session_at]) if @options[:resume_session_at]
        args.push('--fork-session') if @options[:fork_session]
        args.push('--continue') if @options[:continue]

        # System prompt - can be string or preset hash
        add_system_prompt_args(args)

        # Tools
        add_tools_args(args)

        # Directories
        @options[:additional_directories]&.each do |dir|
          args.push('--add-dir', dir.to_s)
        end

        # Streaming & Output
        args.push('--include-partial-messages') if @options[:include_partial_messages]
        if @options[:output_format]
          args.push('--output-format-json-schema', JSON.generate(@options[:output_format][:schema]))
        end

        # Advanced
        args.push('--enable-file-checkpointing') if @options[:enable_file_checkpointing]
        args.push('--strict-mcp-config') if @options[:strict_mcp_config]

        # Betas
        @options[:betas]&.each do |beta|
          args.push('--beta', beta.to_s)
        end

        # Setting sources
        @options[:setting_sources]&.each do |source|
          args.push('--setting-source', source.to_s)
        end

        # MCP servers (passed as JSON config)
        if @options[:mcp_servers]&.any?
          args.push('--mcp-config', JSON.generate(@options[:mcp_servers]))
        end

        # Plugins
        @options[:plugins]&.each do |plugin|
          args.push('--plugin', plugin[:path]) if plugin[:type] == 'local'
        end

        # Agents (subagent definitions)
        if @options[:agents]&.any?
          args.push('--agents-config', JSON.generate(@options[:agents]))
        end

        # Sandbox configuration
        if @options[:sandbox]
          args.push('--sandbox-config', JSON.generate(@options[:sandbox]))
        end

        # Extra args
        @options[:extra_args]&.each do |key, value|
          if value.nil?
            args.push("--#{key}")
          else
            args.push("--#{key}", value.to_s)
          end
        end

        # Prompt is passed as final positional argument (safe - no shell expansion)
        args.push(prompt)

        args
      end

      def add_system_prompt_args(args)
        case @options[:system_prompt]
        when String
          args.push('--system-prompt', @options[:system_prompt])
        when Hash
          if @options[:system_prompt][:type] == 'preset'
            args.push('--system-prompt-preset', @options[:system_prompt][:preset])
            args.push('--system-prompt-append', @options[:system_prompt][:append]) if @options[:system_prompt][:append]
          end
        end
      end

      def add_tools_args(args)
        # Tools preset or explicit list
        case @options[:tools]
        when Hash
          args.push('--tools-preset', @options[:tools][:preset]) if @options[:tools][:type] == 'preset'
        when Array
          @options[:tools].each { |t| args.push('--tool', t.to_s) }
        end

        # Allowed/disallowed tools
        @options[:allowed_tools]&.each { |t| args.push('--allowed-tool', t.to_s) }
        @options[:disallowed_tools]&.each { |t| args.push('--disallowed-tool', t.to_s) }
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
