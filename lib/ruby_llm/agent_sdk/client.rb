# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # Client provides a stateful, multi-turn interface to Claude Code CLI.
    #
    # Unlike one-off queries, the Client maintains conversation context across
    # multiple interactions by tracking the session ID.
    #
    # == Why `query` instead of `ask`?
    #
    # The `query` method returns a lazy Enumerator that streams messages as they
    # arrive from the CLI. This differs from Chat#ask which blocks until complete
    # and returns a single Message. The naming reflects these semantic differences:
    #
    # - `ask`: Question/answer pattern, returns final response (Chat)
    # - `query`: Command/stream pattern, returns message stream (AgentSDK)
    #
    # This also maintains parity with the official Claude Code SDK naming.
    #
    # @example Basic multi-turn conversation
    #   client = RubyLLM::AgentSDK.client
    #   client.query("Hello!").each { |msg| puts msg.content }
    #   client.query("What did I just say?").each { |msg| puts msg.content }
    #
    # @example With fluent configuration
    #   client = RubyLLM::AgentSDK.client
    #     .with_model(:claude_sonnet)
    #     .with_permission_mode(:auto_accept)
    #     .with_max_turns(10)
    #
    #   client.query("Refactor this file").each do |message|
    #     puts message.content if message.assistant?
    #   end
    #
    # @example Collecting the final result
    #   result = client.query("What is 2+2?").find(&:result?)
    #   puts result.content
    #
    class Client
      attr_reader :session_id, :options

      def initialize(**options)
        @options = Options.new(**options)
        @session_id = nil
        @cli = nil
        @mutex = Mutex.new
        @hook_runner = Hooks::Runner.new(@options.hooks)
        @session_context = {}
      end

      def query(prompt)
        opts = @options.to_cli_args
        opts[:resume] = @session_id if @session_id
        is_resume = !@session_id.nil?

        Enumerator.new do |yielder|
          @cli = CLI.new(opts)

          @cli.stream(prompt) do |line|
            message = Stream.parse(line)
            next unless message

            # Capture session context from init message
            if message.init?
              @session_context[:session_id] = message.session_id
              @session_context[:cwd] = message.cwd
              @session_context[:permission_mode] = message.permission_mode

              # Fire session_start hook (with appropriate source)
              @hook_runner.run(
                :session_start,
                metadata: { source: is_resume ? 'resume' : 'startup', **@session_context }
              )
            end

            # Fire pre_tool_use hooks for tool use messages
            if message.tool_use?
              blocked = false
              message.tool_use_blocks.each do |tool_block|
                result = @hook_runner.run(
                  :pre_tool_use,
                  tool_name: tool_block[:name],
                  tool_input: tool_block[:input],
                  metadata: { tool_use_id: tool_block[:id], **@session_context }
                )

                if result.blocked?
                  blocked = true
                  break
                end
              end
              next if blocked
            end

            # Capture session ID from result message
            @session_id ||= message.session_id if message.result?

            yielder << message
          end

          # Fire session_end hook
          @hook_runner.run(
            :session_end,
            metadata: { reason: 'completed', **@session_context }
          )
        ensure
          @mutex.synchronize { @cli = nil }
        end.lazy
      end

      def abort
        @mutex.synchronize { @cli&.abort }
      end

      def close
        abort
        @session_id = nil
      end

      def capabilities
        {
          tools: @options.allowed_tools,
          permission_mode: @options.permission_mode,
          max_turns: @options.max_turns,
          model: @options.model
        }
      end

      # Fluent interface delegation
      def with_tools(*tools)
        @options.with_tools(*tools)
        self
      end

      def with_model(model)
        @options.with_model(model)
        self
      end

      def with_permission_mode(mode)
        @options.with_permission_mode(mode)
        self
      end

      def with_cwd(path)
        @options.with_cwd(path)
        self
      end

      def with_system_prompt(prompt)
        @options.with_system_prompt(prompt)
        self
      end

      def with_max_turns(turns)
        @options.with_max_turns(turns)
        self
      end

      def with_hooks(hooks)
        @options.with_hooks(hooks)
        @hook_runner = Hooks::Runner.new(@options.hooks)
        self
      end
    end
  end
end
