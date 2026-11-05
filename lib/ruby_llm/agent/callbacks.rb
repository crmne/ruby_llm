# frozen_string_literal: true

module RubyLLM
  class Agent
    # The Agent callback macros, such as Agent::after_message, which
    # register the Chat callback of the same name on every chat an agent
    # builds or finds. Each runs on the agent instance, like a Rails
    # callback on its record.
    module Callbacks # :nodoc:
      HOOKS = %i[
        before_request before_message after_message before_tool_call after_tool_result after_tool_progress
        before_fallback after_fallback after_file_write
      ].freeze

      # A declared callback: a method name or a block, with the +if:+ and
      # +unless:+ conditions that guard it.
      class Callback # :nodoc:
        def initialize(hook, method_name, block, conditions)
          unless method_name.nil? ^ block.nil?
            raise ArgumentError, "#{hook} takes a method name or a block, not both or neither"
          end

          unknown = conditions.keys - %i[if unless]
          raise ArgumentError, "#{hook} takes if: and unless:, got #{unknown.join(', ')}" if unknown.any?

          @handler = method_name || block
          @if = Array(conditions[:if])
          @unless = Array(conditions[:unless])
        end

        def run(agent, args)
          return unless @if.all? { |condition| call(agent, condition, args) }
          return if @unless.any? { |condition| call(agent, condition, args) }

          call(agent, @handler, args)
        end

        private

        def call(agent, handler, args)
          if handler.is_a?(Symbol) || handler.is_a?(String)
            method = agent.method(handler)
            return method.arity.zero? ? method.call : method.call(*args)
          end

          handler.lambda? && handler.arity.zero? ? agent.instance_exec(&handler) : agent.instance_exec(*args, &handler)
        end
      end

      HOOKS.each do |hook|
        define_method(hook) do |method_name = nil, **conditions, &block|
          chat_callbacks << [hook, Callback.new(hook, method_name, block, conditions)]
          self
        end
      end

      def chat_callbacks
        @chat_callbacks ||= []
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@chat_callbacks, chat_callbacks.dup)
      end

      def apply_configuration(chat, input_values:, agent: nil, **)
        super.tap do
          next if chat_callbacks.empty?

          receiver = agent || allocate.bind(chat, input_values)
          chat_callbacks.each do |hook, callback|
            chat.public_send(hook) { |*args| callback.run(receiver, args) }
          end
        end
      end
    end
  end
end
