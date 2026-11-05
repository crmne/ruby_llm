# frozen_string_literal: true

module RubyLLM
  class Agent
    # Applies the Agent::owner macro's owner to every chat an agent builds
    # or finds, with Chat#with_owner, and hands it to subclasses. The owner
    # is set once the chat has its context, and before the instructions
    # and tools that may read it.
    module Ownership # :nodoc:
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@owner, @owner)
      end

      private

      def apply_context(chat, runtime, **)
        super.tap { chat.with_owner(evaluate(owner, runtime)) unless owner.nil? }
      end
    end
  end
end
