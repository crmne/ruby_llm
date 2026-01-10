# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    class Client
      attr_reader :session_id, :options

      def initialize(**options)
        @options = Options.new(**options)
        @session_id = nil
        @cli = nil
        @mutex = Mutex.new
      end

      def query(prompt)
        opts = @options.to_cli_args
        opts[:resume] = @session_id if @session_id

        Enumerator.new do |yielder|
          @cli = CLI.new(opts)

          @cli.stream(prompt) do |line|
            message = Stream.parse(line)
            next unless message

            # Capture session ID from result message
            @session_id ||= message.session_id if message.result?

            yielder << message
          end
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
    end
  end
end
