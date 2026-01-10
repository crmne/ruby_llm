# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # High-level client for multi-turn conversations with Claude
    #
    # The Client manages conversation state, sessions, and provides
    # a convenient interface for interactive agent workflows.
    #
    # @example Basic usage
    #   client = Client.new(permission_mode: :accept_edits)
    #
    #   client.query("Create a hello world script") do |msg|
    #     puts msg.content if msg.assistant?
    #   end
    #
    #   # Continue the conversation
    #   client.query("Now add error handling") do |msg|
    #     puts msg.content if msg.assistant?
    #   end
    #
    # @example With streaming Enumerator
    #   client = Client.new
    #
    #   client.stream("Analyze this codebase").each do |message|
    #     case message.type
    #     when :assistant then print message.content
    #     when :tool_use then log_tool(message)
    #     when :result then handle_result(message)
    #     end
    #   end
    class Client
      attr_reader :options, :cli, :session_id, :conversation_history

      # @param options [Options, Hash] Configuration options
      # @param cli [CLI] Optional CLI instance (creates one if not provided)
      def initialize(options: nil, cli: nil, **option_args)
        @options = build_options(options, option_args)
        @cli = cli || CLI.new(options: @options)
        @session_id = nil
        @conversation_history = []
        @tool_registry = ToolRegistry.new
        @callbacks = {}
      end

      # Send a query and yield messages
      #
      # @param prompt [String] The prompt to send
      # @param options [Hash] Override options for this query
      # @yield [Message] Each message from the response
      # @return [Message, nil] The final result message
      def query(prompt, **override_options, &block)
        merged = merge_options(override_options)

        # Continue session if we have one
        merged.resume = @session_id if @session_id && !merged.resume

        result = nil
        @cli.query(prompt, options: merged) do |message|
          process_message(message)
          block&.call(message)
          result = message if message.result?
        end

        # Store session for continuation
        @session_id = result&.session_id

        result
      end

      # Stream messages as an Enumerator
      #
      # @param prompt [String] The prompt to send
      # @param options [Hash] Override options
      # @return [Enumerator<Message>]
      def stream(prompt, **override_options)
        merged = merge_options(override_options)
        merged.resume = @session_id if @session_id && !merged.resume

        Enumerator.new do |yielder|
          @cli.stream(prompt, options: merged).each do |message|
            process_message(message)
            yielder << message
            @session_id = message.session_id if message.result?
          end
        end
      end

      # Register a custom tool
      #
      # @param tool [Tool] Tool to register
      # @return [Tool]
      def register_tool(tool)
        @tool_registry.register(tool)
      end

      # Define a tool with a block
      #
      # @param name [String, Symbol] Tool name
      # @param description [String] Tool description
      # @param input_schema [Hash] Input schema
      # @yield [Hash] Tool handler
      # @return [Tool]
      def tool(name, description:, input_schema: {}, &handler)
        t = Tool.new(name: name, description: description, input_schema: input_schema, &handler)
        register_tool(t)
      end

      # Register a callback for events
      #
      # @param event [Symbol] Event type (:message, :tool_use, :result, :error)
      # @yield [Message] Callback handler
      # @return [void]
      def on(event, &block)
        @callbacks[event] ||= []
        @callbacks[event] << block
      end

      # Reset conversation state (start fresh)
      #
      # @return [void]
      def reset!
        @session_id = nil
        @conversation_history = []
      end

      # Abort the current operation
      #
      # @return [void]
      def abort!
        @cli.abort!
      end

      # Get the current session
      #
      # @return [Session, nil]
      def session
        return nil unless @session_id

        Session.new(id: @session_id, history: @conversation_history)
      end

      # Resume a previous session
      #
      # @param session_id [String] Session ID to resume
      # @param fork [Boolean] Fork to a new session
      # @return [self]
      def resume(session_id, fork: false)
        @session_id = session_id
        @options.fork_session = fork
        self
      end

      # Get usage statistics for the session
      #
      # @return [Hash]
      def usage
        results = @conversation_history.select(&:result?)
        return {} if results.empty?

        {
          total_cost_usd: results.sum { |r| r.cost_usd || 0 },
          total_input_tokens: results.sum { |r| r.input_tokens || 0 },
          total_output_tokens: results.sum { |r| r.output_tokens || 0 },
          turns: results.size
        }
      end

      private

      def build_options(options, args)
        case options
        when Options
          options
        when Hash
          Options.new(**options.merge(args))
        when nil
          Options.new(**args)
        else
          raise ArgumentError, "Invalid options: #{options.class}"
        end
      end

      def merge_options(overrides)
        return @options if overrides.empty?

        merged = Options.new(**@options.to_h)
        overrides.each do |key, value|
          merged.send(:"#{key}=", value) if merged.respond_to?(:"#{key}=")
        end
        merged
      end

      def process_message(message)
        @conversation_history << message

        # Execute tool calls if we have handlers
        if message.tool_use? && @tool_registry.size.positive?
          handle_tool_call(message)
        end

        # Fire callbacks
        fire_callbacks(:message, message)

        case message.type
        when :assistant
          fire_callbacks(:assistant, message)
        when :tool_use
          fire_callbacks(:tool_use, message)
        when :result
          fire_callbacks(:result, message)
        when :error
          fire_callbacks(:error, message)
        end
      end

      def handle_tool_call(message)
        tool_name = message.data[:tool_name] || message.data['tool_name']
        tool_input = message.data[:tool_input] || message.data['tool_input'] || {}

        return unless @tool_registry.include?(tool_name)

        begin
          result = @tool_registry.call(tool_name, **tool_input.transform_keys(&:to_sym))
          fire_callbacks(:tool_result, { tool: tool_name, result: result })
        rescue StandardError => e
          fire_callbacks(:tool_error, { tool: tool_name, error: e })
        end
      end

      def fire_callbacks(event, data)
        return unless @callbacks[event]

        @callbacks[event].each { |cb| cb.call(data) }
      end
    end
  end
end
