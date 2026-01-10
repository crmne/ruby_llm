# frozen_string_literal: true

require 'open3'
require 'timeout'

module RubyLLM
  module AgentSDK
    # Claude CLI subprocess management
    #
    # Handles spawning and communicating with the Claude CLI process.
    # Supports streaming output via Enumerator and proper process lifecycle.
    #
    # @example Simple query
    #   cli = CLI.new
    #   cli.query("What is 2+2?") do |message|
    #     puts message.content if message.assistant?
    #   end
    #
    # @example Streaming with Enumerator
    #   cli = CLI.new(permission_mode: :accept_edits)
    #   cli.stream("Fix the bug in main.rb").each do |message|
    #     process_message(message)
    #   end
    class CLI
      # Default CLI executable
      DEFAULT_EXECUTABLE = 'claude'

      # Default buffer size for stdout reads
      DEFAULT_BUFFER_SIZE = 16_384

      attr_reader :executable, :options, :hook_runner

      # @param executable [String] Path to claude CLI
      # @param options [Options] Configuration options
      def initialize(executable: DEFAULT_EXECUTABLE, options: nil)
        @executable = executable
        @options = options || Options.new
        @hook_runner = Hooks::Runner.new(@options.hooks)
        @process = nil
        @aborted = false
      end

      # Check if the Claude CLI is available
      #
      # @return [Boolean]
      def self.available?
        system('which claude > /dev/null 2>&1')
      end

      # Get CLI version
      #
      # @return [String, nil]
      def self.version
        output, status = Open3.capture2('claude', '--version')
        return nil unless status.success?

        output.strip
      rescue Errno::ENOENT
        nil
      end

      # Send a query and yield each message
      #
      # @param prompt [String] The prompt to send
      # @param options [Options] Override options
      # @yield [Message] Each message from the stream
      # @return [Message, nil] The final result message
      def query(prompt, options: nil, &block)
        merged_options = merge_options(options)
        result = nil

        stream(prompt, options: merged_options).each do |message|
          block&.call(message)
          result = message if message.result?
        end

        result
      end

      # Stream messages from a query as an Enumerator
      #
      # @param prompt [String] The prompt to send
      # @param options [Options] Override options
      # @return [Enumerator<Message>]
      def stream(prompt, options: nil)
        merged_options = merge_options(options)

        Enumerator.new do |yielder|
          run_cli(prompt, merged_options) do |line|
            message = Stream.parse(line)
            next unless message

            # Run post-processing hooks
            if message.tool_use?
              hook_result = @hook_runner.run(
                :pre_tool_use,
                tool_name: message.data[:tool_name] || message.data['tool_name'],
                tool_input: message.data[:tool_input] || message.data['tool_input']
              )

              if hook_result.blocked?
                # Skip blocked tool uses
                next
              end
            end

            yielder << message
          end
        end
      end

      # Abort the current operation
      #
      # @return [void]
      def abort!
        @aborted = true
        kill_process
      end

      # Check if operation was aborted
      #
      # @return [Boolean]
      def aborted?
        @aborted
      end

      # Send input to running process
      #
      # @param text [String] Input to send
      # @return [void]
      def send_input(text)
        return unless @stdin&.respond_to?(:puts)

        @stdin.puts(text)
        @stdin.flush
      end

      private

      def merge_options(override)
        return @options unless override

        merged = Options.new(**@options.to_h)
        override.to_h.each do |key, value|
          merged.send(:"#{key}=", value) if merged.respond_to?(:"#{key}=")
        end
        merged
      end

      def run_cli(prompt, options)
        args = build_args(prompt, options)
        env = build_env(options)

        buffer_size = options.respond_to?(:max_buffer_size) ? options.max_buffer_size : nil
        buffer_size ||= DEFAULT_BUFFER_SIZE

        @aborted = false

        with_timeout(options.timeout) do
          Open3.popen3(env, executable, *args) do |stdin, stdout, stderr, wait_thr|
            @stdin = stdin
            @process = wait_thr

            stdin.close # Close stdin unless we need interactive input

            # Read stdout line by line
            stdout.each_line do |line|
              break if @aborted

              line = line.chomp
              next if line.empty?

              yield line
            end

            # Check for errors
            exit_status = wait_thr.value
            unless exit_status.success? || @aborted
              stderr_output = stderr.read
              raise ProcessError.new(
                "Claude CLI exited with status #{exit_status.exitstatus}",
                exit_code: exit_status.exitstatus,
                stderr: stderr_output
              )
            end
          end
        end
      rescue Errno::ENOENT
        raise CLINotFoundError, "Claude CLI not found at '#{executable}'"
      ensure
        @stdin = nil
        @process = nil
      end

      def build_args(prompt, options)
        args = ['--output-format', 'stream-json']

        # Print mode for non-interactive
        args += ['--print']

        # Model
        if options.model
          args += ['--model', options.model.to_s]
        end

        # Max turns
        if options.max_turns
          args += ['--max-turns', options.max_turns.to_s]
        end

        # Permission mode
        case options.permission_mode
        when :bypass_permissions
          args += ['--dangerously-skip-permissions']
        when :accept_edits
          args += ['--allowedTools', 'Edit,Write,Bash']
        end

        # Working directory
        if options.cwd
          args += ['--cwd', options.cwd]
        end

        # Resume session
        if options.resume
          args += ['--resume', options.resume]
        elsif options.continue_conversation
          args += ['--continue']
        end

        # System prompt
        if options.system_prompt
          args += ['--system-prompt', options.system_prompt]
        end

        # Add the prompt
        args += ['-p', prompt]

        args
      end

      def build_env(options)
        env = {}

        # Merge custom environment variables
        env.merge!(options.env) if options.env

        env
      end

      def with_timeout(timeout_seconds)
        return yield unless timeout_seconds

        Timeout.timeout(timeout_seconds) { yield }
      rescue Timeout::Error
        kill_process
        raise TimeoutError, "Operation timed out after #{timeout_seconds} seconds"
      end

      def kill_process
        return unless @process

        begin
          Process.kill('TERM', @process.pid)
          sleep 0.1
          Process.kill('KILL', @process.pid) if @process.alive?
        rescue Errno::ESRCH, Errno::EPERM
          # Process already gone or not permitted
        end
      end
    end
  end
end
