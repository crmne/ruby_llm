# frozen_string_literal: true

require_relative 'agent/tools'
require_relative 'agent/hooks'
require_relative 'agent/permissions'

module RubyLLM
  # An autonomous agent that uses RubyLLM::Chat with built-in tools for
  # file operations, code editing, and command execution.
  #
  # Example:
  #   agent = RubyLLM::Agent.new
  #     .with_tools(RubyLLM::Agent::Tools::Read, RubyLLM::Agent::Tools::Edit)
  #     .with_permission(:allow_all)
  #
  #   agent.run("Find and fix the bug in auth.rb") do |event|
  #     case event.type
  #     when :message then puts event.content
  #     when :tool_call then puts "Using #{event.tool_name}..."
  #     when :tool_result then puts "Result: #{event.result}"
  #     end
  #   end
  class Agent
    attr_reader :chat, :hooks, :permissions, :max_turns

    # @param model [String] Model ID to use (defaults to config default)
    # @param provider [Symbol] Provider to use
    # @param max_turns [Integer] Maximum tool execution loops (default: 10)
    def initialize(model: nil, provider: nil, max_turns: 10)
      @chat = Chat.new(model: model, provider: provider)
      @hooks = Hooks.new
      @permissions = Permissions.new
      @max_turns = max_turns
      @current_turn = 0
      @on = {}
    end

    # Add a tool to the agent
    #
    # @param tool [Class, RubyLLM::Tool] Tool class or instance
    # @return [self]
    def with_tool(tool)
      @chat.with_tool(tool)
      self
    end

    # Add multiple tools
    #
    # @param tools [Array<Class, RubyLLM::Tool>] Tools to add
    # @return [self]
    def with_tools(*tools)
      tools.flatten.each { |t| with_tool(t) }
      self
    end

    # Set permission mode
    #
    # @param mode [Symbol] :allow_all, :deny_all, or :ask
    # @return [self]
    def with_permission(mode)
      @permissions.mode = mode
      self
    end

    # Add a pre-tool hook
    #
    # @param tool_pattern [String, Regexp, nil] Tool name pattern to match
    # @yield [HookContext] Called before tool execution
    # @return [self]
    def before_tool(tool_pattern = nil, &block)
      @hooks.add(:before, tool_pattern, &block)
      self
    end

    # Add a post-tool hook
    #
    # @param tool_pattern [String, Regexp, nil] Tool name pattern to match
    # @yield [HookContext] Called after tool execution
    # @return [self]
    def after_tool(tool_pattern = nil, &block)
      @hooks.add(:after, tool_pattern, &block)
      self
    end

    # Set maximum turns (tool execution loops)
    #
    # @param turns [Integer]
    # @return [self]
    def with_max_turns(turns)
      @max_turns = turns
      self
    end

    # Set the model
    #
    # @param model_id [String] Model identifier
    # @param provider [Symbol] Optional provider
    # @return [self]
    def with_model(model_id, provider: nil)
      @chat.with_model(model_id, provider: provider)
      self
    end

    # Set temperature
    #
    # @param temp [Float]
    # @return [self]
    def with_temperature(temp)
      @chat.with_temperature(temp)
      self
    end

    # Register event callback
    #
    # @param event [Symbol] :message, :tool_call, :tool_result, :turn, :complete
    # @yield [Event] Event data
    # @return [self]
    def on(event, &block)
      @on[event] = block
      self
    end

    # Run the agent with a prompt
    #
    # @param prompt [String] The task or question
    # @yield [Event] Events as they occur
    # @return [Message] Final response
    def run(prompt, &block)
      @current_turn = 0
      @block = block

      # Set up chat callbacks to intercept events
      setup_chat_callbacks

      # Start the conversation
      @chat.ask(prompt) do |chunk|
        emit(:chunk, chunk)
      end
    end

    alias ask run

    # Get conversation messages
    #
    # @return [Array<Message>]
    def messages
      @chat.messages
    end

    private

    Event = Struct.new(:type, :data, keyword_init: true) do
      def method_missing(name, *args)
        data.respond_to?(name) ? data.send(name, *args) : data[name]
      end

      def respond_to_missing?(name, include_private = false)
        data.respond_to?(name) || data.key?(name) || super
      end
    end

    def setup_chat_callbacks
      @chat.on_new_message do
        @current_turn += 1
        emit(:turn, { turn: @current_turn, max_turns: @max_turns })

        if @current_turn > @max_turns
          raise MaxTurnsExceededError, "Agent exceeded #{@max_turns} turns"
        end
      end

      @chat.on_end_message do |message|
        if message.tool_call?
          message.tool_calls.each_value do |tool_call|
            handle_tool_call_event(tool_call)
          end
        else
          emit(:message, message)
        end
      end
    end

    def handle_tool_call_event(tool_call)
      # Check permissions
      unless @permissions.allowed?(tool_call.name, tool_call.arguments)
        emit(:tool_denied, {
          tool_name: tool_call.name,
          arguments: tool_call.arguments,
          reason: @permissions.denial_reason
        })
        raise PermissionDeniedError, "Tool #{tool_call.name} not permitted"
      end

      # Run before hooks
      context = HookContext.new(
        tool_name: tool_call.name,
        arguments: tool_call.arguments,
        phase: :before
      )
      @hooks.run(:before, context)

      return if context.blocked?

      emit(:tool_call, {
        tool_name: tool_call.name,
        arguments: context.arguments
      })
    end

    def emit(type, data)
      event = Event.new(type: type, data: data)
      @on[type]&.call(event)
      @block&.call(event)
    end

    # Hook context passed to hook callbacks
    HookContext = Struct.new(:tool_name, :arguments, :result, :phase, :blocked, keyword_init: true) do
      def block!
        self.blocked = true
      end

      def blocked?
        blocked == true
      end

      def modify_arguments(new_args)
        self.arguments = new_args
      end
    end
  end

  # Errors
  class MaxTurnsExceededError < Error; end
  class PermissionDeniedError < Error; end
end
