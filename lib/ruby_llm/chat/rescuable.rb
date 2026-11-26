# frozen_string_literal: true

module RubyLLM
  class Chat
    # Runs a chat's operations through the Agent::rescue_from handlers of the
    # agent that configured it, however the chat was reached. Only the
    # outermost operation rescues: #ask runs #complete, and a handler's value
    # must not stand in for a step of a loop that is still running.
    module Rescuable # :nodoc:
      OPERATIONS = %i[ask say ask_later complete generate run_tools step count_tokens compact].freeze

      attr_writer :rescuer

      # The agents whose callback macros run on this chat, by agent class.
      def agent_callback_receivers
        @agent_callback_receivers ||= {}
      end

      # A copy of the chat builds these blocks again, so another agent that
      # takes it over gets its own callbacks.
      def agent_callback(agent_class, callback)
        receivers = agent_callback_receivers
        block = proc { |*args, &run| callback.run(receivers[agent_class], args, &run) }
        agent_callbacks[block] = [agent_class, callback]
        block
      end

      OPERATIONS.each do |operation|
        define_method(operation) do |*args, **kwargs, &block|
          return super(*args, **kwargs, &block) unless @rescuer

          rescuing_with(@rescuer) { super(*args, **kwargs, &block) }
        end
      end

      def rescuing_with(agent)
        return yield if @rescuing

        begin
          @rescuing = true
          yield
        rescue StandardError => e
          @rescuing = false
          agent.rescue_with_handler(e)
        ensure
          @rescuing = false
        end
      end

      def initialize_copy(source)
        super
        @rescuing = false
        @agent_callback_receivers = agent_callback_receivers.dup
        rebind_agent_callbacks
      end

      private

      def agent_callbacks
        @agent_callbacks ||= {}.compare_by_identity
      end

      def rebind_agent_callbacks
        source = agent_callbacks
        @agent_callbacks = {}.compare_by_identity
        @callbacks&.transform_values! do |callbacks|
          callbacks.map { |block| source.key?(block) ? agent_callback(*source[block]) : block }
        end
      end
    end
  end
end
