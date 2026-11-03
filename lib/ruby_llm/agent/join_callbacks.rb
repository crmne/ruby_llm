# frozen_string_literal: true

module RubyLLM
  class Agent
    # The Agent::around_join macro, which registers Chat#around_join
    # callbacks on every chat an agent builds or finds.
    module JoinCallbacks # :nodoc:
      def around_join(&block)
        raise ArgumentError, 'around_join needs a block' unless block

        around_join_callbacks << block
      end

      def around_join_callbacks
        @around_join_callbacks ||= []
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@around_join_callbacks, around_join_callbacks.dup)
      end

      def apply_configuration(chat, **)
        super.tap { around_join_callbacks.each { |callback| chat.around_join(&callback) } }
      end
    end
  end
end
